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
      result = +""
      position = 0
      text.scan(PROTECTED_ELEMENTS) do
        match = Regexp.last_match
        result << resolve_unprotected(text[position...match.begin(0)], doc_path)
        result << restore_protected_sources(match[0])
        position = match.end(0)
      end
      result << resolve_unprotected(text[position..].to_s, doc_path)
      return result
    end

    # immediate rendering of both notations in a plain string
    def render_math(text, doc_path)
      text = text.gsub(INLINE_MATH) { render_expression($2, display_mode: false, doc_path: doc_path) }
      return text.gsub(DISPLAY_MATH) { render_expression($2, display_mode: true, doc_path: doc_path) }
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

    def resolve_unprotected(segment, doc_path)
      segment = render_math(segment, doc_path)
      return segment.gsub(TOKEN) do |token|
        expression = @protected_math[token]
        if expression
          render_expression(expression.body,
                            display_mode: expression.display_mode,
                            doc_path: doc_path)
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

    def render_expression(expression, display_mode:, doc_path:)
      expression = @entity_parser.decode(expression)

      if (cached_html = @cache.fetch(expression, display_mode))
        @cache_hit_count += 1
        @reporter.progress(@rendered_count, @cache_hit_count)
        return cached_html
      end

      begin
        html = @renderer.render(expression, display_mode: display_mode)
      rescue SystemExit, Interrupt
        # save the work done so far, then let Jekyll die properly
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
