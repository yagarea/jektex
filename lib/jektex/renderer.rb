require 'execjs'

module Jektex
  # Wraps the bundled KaTeX JavaScript. Knows nothing about pages,
  # caching or Jekyll — it turns expressions into HTML.
  class Renderer
    # With an external ExecJS runtime (node, bun) every call spawns a fresh
    # process that has to parse the whole KaTeX bundle (~70 ms), while the
    # rendering itself takes single milliseconds. Rendering a whole batch
    # of expressions in one call amortizes that overhead.
    BATCH_HELPER = <<~JS
      function jektexRenderBatch(items) {
        return items.map(function (item) {
          var expression = item[0];
          var options = item[1];
          try {
            return { html: katex.renderToString(expression, options) };
          } catch (error) {
            var message = String(error.message || error);
            options.throwOnError = false;
            try {
              return { error: message, html: katex.renderToString(expression, options) };
            } catch (unrenderableError) {
              return { error: message, html: null };
            }
          }
        });
      }
    JS

    # error is nil for successful renders; html is the rendered expression,
    # for failed ones rendered with the error highlighted in place — or nil
    # when even that was impossible
    RenderedExpression = Struct.new(:html, :error)

    def initialize(config)
      @path_to_katex_js = config.path_to_katex_js
      @global_macros = config.global_macros
      @katex_options = config.katex_options
    end

    # Renders [[expression, display_mode], ...] in one JavaScript call.
    # Returns a RenderedExpression for every item, in the same order.
    # A parse error in one expression does not affect the others.
    def render_batch(expressions)
      return [] if expressions.empty?
      items = expressions.map do |expression, display_mode|
        [expression, base_options(display_mode)]
      end
      results = katex.call("jektexRenderBatch", items)
      return results.map { |result| RenderedExpression.new(result["html"], result["error"]) }
    end

    # Raises ExecJS::ProgramError when the expression is invalid LaTeX.
    def render(expression, display_mode:)
      katex.call("katex.renderToString", expression, base_options(display_mode))
    end

    # Never raises on invalid LaTeX; KaTeX renders the error into the
    # document instead (red highlighting).
    def render_with_error_fallback(expression, display_mode:)
      katex.call("katex.renderToString", expression,
                 base_options(display_mode).merge(throwOnError: false))
    end

    private

    # compiling the KaTeX bundle takes ~100 ms, so defer it to the first
    # render instead of paying for it at plugin load time
    def katex
      @katex ||= ExecJS.compile(File.read(@path_to_katex_js) + BATCH_HELPER)
    end

    # user options first, so the keys jektex decides itself always win
    # (reserved keys are already stripped by the config, this is a backstop)
    def base_options(display_mode)
      @katex_options.merge(displayMode: display_mode,
                           macros: @global_macros)
    end
  end
end
