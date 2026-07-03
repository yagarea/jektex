require 'execjs'
require 'htmlentities'

module Jektex
  # Finds math expressions in a page, decides whether the page should be
  # processed at all, and answers each expression from the cache or by
  # rendering it. This is the orchestration layer between Jekyll hooks
  # and the renderer/cache.
  class PageProcessor
    # The (?<!\\) lookbehind skips escaped delimiters. It is also what
    # prevents the post_render pass from re-matching \\[..] sequences
    # inside the TeX source that KaTeX embeds in its own output.
    INLINE_MATH = /(\\\()(.*?)(?<!\\)\\\)/m
    DISPLAY_MATH = /(\\\[)(.*?)(?<!\\)\\\]/m

    attr_reader :rendered_count, :cache_hit_count

    def initialize(config:, cache:, renderer:, reporter:)
      @config = config
      @cache = cache
      @renderer = renderer
      @reporter = reporter
      @entity_parser = HTMLEntities.new
      reset_counters
    end

    # field is :content (pre_render, raw LaTeX notation) or
    # :output (post_render, kramdown notation converted to \(..\)/\[..\])
    def process(page, field)
      text = page.public_send(field)
      return text if !page.data || ignored?(page)
      return render_math(text.to_s, page.relative_path)
    end

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
