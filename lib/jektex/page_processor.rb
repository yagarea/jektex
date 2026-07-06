require 'digest'
require 'execjs'
require 'htmlentities'

module Jektex
  # Finds math expressions in a page, decides whether the page should be
  # processed at all, and answers each expression from the cache or by
  # rendering it. This is the orchestration layer between Jekyll hooks
  # and the renderer/cache.
  #
  # Rendering happens in two phases. At pre_render every LaTeX-notation
  # expression in the raw content is swapped for an inert token, so Liquid
  # and kramdown treat math like ordinary text and cannot mangle it. At
  # post_render the final HTML structure is known, so tokens inside code
  # markup turn back into their original source text (a code sample about
  # LaTeX must show the LaTeX, see github issue #5) while all other math
  # is rendered.
  #
  # Kramdown notation is converted to LaTeX notation by kramdown itself —
  # except inside raw HTML blocks, which kramdown does not process; the
  # $$..$$ expressions left there are found and rendered too (issue #7),
  # but only for markdown source files, where $$ has a defined meaning.
  #
  # All expressions a page needs are collected first and rendered in one
  # batched KaTeX call, because each call to an external ExecJS runtime
  # costs far more than the rendering itself.
  class PageProcessor
    # The (?<!\\) lookbehind skips escaped delimiters. It is also what
    # prevents the post_render pass from re-matching \\[..] sequences
    # inside the TeX source that KaTeX embeds in its own output.
    INLINE_MATH = /(\\\()(.*?)(?<!\\)\\\)/m
    DISPLAY_MATH = /(\\\[)(.*?)(?<!\\)\\\]/m

    TOKEN = /jektexprotected[0-9a-f]{32}/

    # everything resolve_math reacts to, found in one pass
    MATH_PATTERN = /(?<inline>\\\((?<inline_body>.*?)(?<!\\)\\\))|(?<display>\\\[(?<display_body>.*?)(?<!\\)\\\])|(?<token>#{TOKEN.source})/m

    # kramdown converts its $$..$$ notation everywhere except inside raw
    # HTML blocks; these leftovers in the output of markdown pages are
    # rendered too (github issue #7). (?<!\\) honors \$$ as an opt-out
    # and keeps \$ inside a body from closing the expression.
    DOLLAR_MATH = /(?<dollars>(?<!\\)\$\$(?<dollars_body>.+?)(?<!\\)\$\$)/m

    # never used on protected segments: the dollars alternative could
    # swallow a protection token between two dollar signs there
    MATH_PATTERN_WITH_DOLLARS = /#{MATH_PATTERN.source}|#{DOLLAR_MATH.source}/m

    # markup whose contents must never be rendered
    # (the same set KaTeX's own auto-render extension ignores)
    PROTECTED_ELEMENTS = %r{<(pre|code|script|style|textarea)\b[^>]*>.*?</\1\s*>}mi

    ProtectedExpression = Struct.new(:source, :body, :display_mode)

    # a single substitution: replace text[position, length] with either the
    # rendering of expression body (kind :expression, source is the fallback
    # when rendering is impossible) or a literal string (kind :text)
    Instruction = Struct.new(:position, :length, :kind, :body, :display_mode, :source)

    attr_reader :rendered_count, :cache_hit_count

    def initialize(config:, cache:, renderer:, reporter:)
      @config = config
      @cache = cache
      @renderer = renderer
      @reporter = reporter
      @entity_parser = HTMLEntities.new
      # tokens must stay resolvable across watch-mode rebuilds, because other
      # pages can embed token-carrying content of pages that are not rebuilt
      @protected_math = Hash.new
      # batch results waiting for their first substitution: [expression, mode] => html
      @freshly_rendered = Hash.new
      # failed expressions of the current page: [expression, mode] => fallback html or nil
      @error_fallbacks = Hash.new
      reset_counters
    end

    # pre_render: protect LaTeX-notation math in the raw content
    def process_content(page)
      return page.content if !page.data || ignored?(page)
      text = page.content.to_s
      return text unless text.include?('\(') || text.include?('\[')
      return protect_math(text)
    end

    # post_render: render the protected tokens and the kramdown-notation
    # math (kramdown turns its $$..$$ into \(..\)/\[..\] during conversion,
    # except inside raw HTML blocks, where the $$..$$ survives verbatim)
    def process_output(page)
      return page.output if !page.data || ignored?(page)
      return resolve_math(page.output.to_s, page.relative_path,
                          dollars: markdown_page?(page))
    end

    def protect_math(text)
      text = text.gsub(INLINE_MATH) { protect_expression($~[0], $2, false) }
      return text.gsub(DISPLAY_MATH) { protect_expression($~[0], $2, true) }
    end

    def resolve_math(text, doc_path, dollars: false)
      return text unless contains_math?(text, dollars)
      instructions = collect_instructions(text, dollars)
      render_missing_expressions(instructions, doc_path)
      return apply_instructions(text, instructions, doc_path)
    end

    # immediate rendering in a plain string, without code protection
    def render_math(text, doc_path)
      instructions = Array.new
      scan_segment(text, 0, :plain, instructions)
      render_missing_expressions(instructions, doc_path)
      return apply_instructions(text, instructions, doc_path)
    end

    def ignored?(page)
      front_matter_flag = page.data[@config.front_matter_tag]
      return true if front_matter_flag == false || front_matter_flag == "false"
      return @config.ignore.any? do |pattern|
        File.fnmatch?(pattern, page.relative_path, File::FNM_DOTMATCH)
      end
    end

    def reset_counters
      @rendered_count = 0
      @cache_hit_count = 0
    end

    private

    def contains_math?(text, dollars)
      return true if text.include?('\(') || text.include?('\[') || text.include?("jektexprotected")
      return dollars && text.include?("$$")
    end

    def markdown_page?(page)
      return @config.markdown_extensions.include?(File.extname(page.relative_path.to_s).downcase)
    end

    def protect_expression(source, body, display_mode)
      token = "jektexprotected" + Digest::SHA2.hexdigest(source)[0, 32]
      @protected_math[token] = ProtectedExpression.new(source, body, display_mode)
      return token
    end

    ##### scanning

    def collect_instructions(text, dollars)
      instructions = Array.new
      position = 0
      text.scan(PROTECTED_ELEMENTS) do
        match = Regexp.last_match
        scan_segment(text[position...match.begin(0)], position, :plain, instructions,
                     text: text, dollars: dollars)
        scan_segment(match[0], match.begin(0), :protected, instructions)
        position = match.end(0)
      end
      scan_segment(text[position..].to_s, position, :plain, instructions,
                   text: text, dollars: dollars)
      return instructions
    end

    def scan_segment(segment, offset, kind, instructions, text: segment, dollars: false)
      pattern = dollars ? MATH_PATTERN_WITH_DOLLARS : MATH_PATTERN
      segment.scan(pattern) do
        match = Regexp.last_match
        position = offset + match.begin(0)
        if match[:token]
          expression = @protected_math[match[0]]
          next unless expression
          if kind == :protected
            # a code sample must show the LaTeX source, not the rendering
            instructions.append(Instruction.new(position, match[0].length, :text,
                                                nil, nil, expression.source))
          else
            instructions.append(Instruction.new(position, match[0].length, :expression,
                                                expression.body, expression.display_mode,
                                                expression.source))
          end
        elsif kind == :plain
          # the dollars guard is required: asking a plain MATH_PATTERN
          # match for the group raises IndexError
          if dollars && match[:dollars]
            instructions.append(Instruction.new(position, match[0].length, :expression,
                                                match[:dollars_body],
                                                standalone_line?(text, position, position + match[0].length),
                                                match[0]))
          else
            body = match[:inline_body] || match[:display_body]
            instructions.append(Instruction.new(position, match[0].length, :expression,
                                                body, !match[:display].nil?, match[0]))
          end
        end
      end
    end

    # kramdown renders $$..$$ standing alone on its line(s) as display math
    # and mid-text occurrences as inline math; mirror that on the output text
    def standalone_line?(text, start, stop)
      line_start = start.zero? ? 0 : ((text.rindex("\n", start - 1) || -1) + 1)
      line_end = text.index("\n", stop) || text.length
      return text[line_start...start].match?(/\A\s*\z/) &&
             text[stop...line_end].match?(/\A\s*\z/)
    end

    ##### rendering

    # renders everything the instructions need but the cache cannot answer,
    # in a single call to the JavaScript runtime
    def render_missing_expressions(instructions, doc_path)
      @error_fallbacks = Hash.new
      needed = instructions.filter_map do |instruction|
        next unless instruction.kind == :expression
        [@entity_parser.decode(instruction.body), instruction.display_mode]
      end.uniq
      missing = needed.reject { |expression, mode| @cache.fetch(expression, mode) }
      return if missing.empty?

      begin
        results = @renderer.render_batch(missing)
      rescue SystemExit, Interrupt
        # save the work done so far, then let Jekyll die properly
        @cache.save
        raise
      end

      missing.zip(results) do |(expression, mode), result|
        if result.error
          @reporter.error(result.error, doc_path)
          @error_fallbacks[[expression, mode]] = result.html
        else
          @cache.store(expression, mode, result.html)
          @freshly_rendered[[expression, mode]] = result.html
        end
      end
    end

    def apply_instructions(text, instructions, doc_path)
      result = +""
      position = 0
      instructions.each do |instruction|
        result << text[position...instruction.position]
        result << if instruction.kind == :text
                    instruction.source
                  else
                    render_expression(instruction.body,
                                      display_mode: instruction.display_mode,
                                      doc_path: doc_path) || instruction.source
                  end
        position = instruction.position + instruction.length
      end
      result << text[position..].to_s
      return result
    end

    # Returns nil only for expressions that failed so hard that not even
    # error highlighting could be rendered — callers keep the source text.
    def render_expression(expression, display_mode:, doc_path:)
      expression = @entity_parser.decode(expression)
      key = [expression, display_mode]

      return @error_fallbacks[key] if @error_fallbacks.key?(key)

      if (batched_html = @freshly_rendered.delete(key))
        @rendered_count += 1
        @reporter.progress(@rendered_count, @cache_hit_count)
        return batched_html
      end

      if (cached_html = @cache.fetch(expression, display_mode))
        @cache_hit_count += 1
        @reporter.progress(@rendered_count, @cache_hit_count)
        return cached_html
      end

      # not covered by the batch — render it individually
      begin
        html = @renderer.render(expression, display_mode: display_mode)
      rescue SystemExit, Interrupt
        @cache.save
        raise
      rescue ExecJS::ProgramError => error
        @reporter.error(error.message, doc_path)
        return @renderer.render_with_error_fallback(expression, display_mode: display_mode)
      end

      @cache.store(expression, display_mode, html)
      @rendered_count += 1
      @reporter.progress(@rendered_count, @cache_hit_count)
      return html
    end
  end
end
