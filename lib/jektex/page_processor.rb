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
  # All expressions a page needs are collected first and rendered in one
  # batched KaTeX call, because each call to an external ExecJS runtime
  # costs far more than the rendering itself.
  class PageProcessor
    # The (?<!\\) lookbehind skips escaped delimiters. It is also what
    # prevents the post_render pass from re-matching \\[..] sequences
    # inside the TeX source that KaTeX embeds in its own output.
    INLINE_MATH = /(\\\()(.*?)(?<!\\)\\\)/m
    DISPLAY_MATH = /(\\\[)(.*?)(?<!\\)\\\]/m

    # markup whose contents must never be rendered
    # (the same set KaTeX's own auto-render extension ignores)
    PROTECTED_ELEMENTS = %r{<(pre|code|script|style|textarea)\b[^>]*>.*?</\1\s*>}mi

    TOKEN = /jektexprotected[0-9a-f]{32}/

    ProtectedExpression = Struct.new(:source, :body, :display_mode)

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
      return protect_math(page.content.to_s)
    end

    # post_render: render the protected tokens and the kramdown-notation
    # math (kramdown turns its $$..$$ into \(..\)/\[..\] during conversion)
    def process_output(page)
      return page.output if !page.data || ignored?(page)
      return resolve_math(page.output.to_s, page.relative_path)
    end

    def protect_math(text)
      text = text.gsub(INLINE_MATH) { protect_expression($~[0], $2, false) }
      return text.gsub(DISPLAY_MATH) { protect_expression($~[0], $2, true) }
    end

    def resolve_math(text, doc_path)
      segments = split_on_protected_elements(text)
      plain_texts = segments.filter_map { |kind, segment| segment if kind == :plain }
      render_needed_expressions(plain_texts, doc_path)
      return segments.map do |kind, segment|
        kind == :plain ? substitute_math(segment, doc_path) : restore_protected_sources(segment)
      end.join
    end

    # immediate rendering of both notations in a plain string
    def render_math(text, doc_path)
      render_needed_expressions([text], doc_path)
      return substitute_math(text, doc_path)
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

    def protect_expression(source, body, display_mode)
      token = "jektexprotected" + Digest::SHA2.hexdigest(source)[0, 32]
      @protected_math[token] = ProtectedExpression.new(source, body, display_mode)
      return token
    end

    def split_on_protected_elements(text)
      segments = Array.new
      position = 0
      text.scan(PROTECTED_ELEMENTS) do
        match = Regexp.last_match
        segments.append([:plain, text[position...match.begin(0)]])
        segments.append([:protected, match[0]])
        position = match.end(0)
      end
      segments.append([:plain, text[position..].to_s])
      return segments
    end

    # renders everything the texts need but the cache cannot answer,
    # in a single call to the JavaScript runtime
    def render_needed_expressions(texts, doc_path)
      @error_fallbacks = Hash.new
      needed = texts.flat_map { |text| collect_expressions(text) }.uniq
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

    def collect_expressions(text)
      needed = Array.new
      text.scan(INLINE_MATH) { |groups| needed.append([@entity_parser.decode(groups[1]), false]) }
      text.scan(DISPLAY_MATH) { |groups| needed.append([@entity_parser.decode(groups[1]), true]) }
      text.scan(TOKEN) do |token|
        expression = @protected_math[token]
        next unless expression
        needed.append([@entity_parser.decode(expression.body), expression.display_mode])
      end
      return needed
    end

    def substitute_math(text, doc_path)
      text = text.gsub(INLINE_MATH) do
        source = $~[0]
        render_expression($2, display_mode: false, doc_path: doc_path) || source
      end
      text = text.gsub(DISPLAY_MATH) do
        source = $~[0]
        render_expression($2, display_mode: true, doc_path: doc_path) || source
      end
      return text.gsub(TOKEN) do |token|
        expression = @protected_math[token]
        if expression
          render_expression(expression.body,
                            display_mode: expression.display_mode,
                            doc_path: doc_path) || expression.source
        else
          token
        end
      end
    end

    def restore_protected_sources(segment)
      return segment.gsub(TOKEN) do |token|
        expression = @protected_math[token]
        expression ? expression.source : token
      end
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

      # not covered by the batch — e.g. revealed by an earlier substitution
      # or invalidated by an updated macro — so render it individually
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
