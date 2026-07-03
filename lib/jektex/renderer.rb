require 'execjs'

module Jektex
  # Wraps the bundled KaTeX JavaScript. Knows nothing about pages,
  # caching or Jekyll — it turns a single expression into HTML.
  class Renderer
    def initialize(config)
      @path_to_katex_js = config.path_to_katex_js
      @global_macros = config.global_macros
      @trust = config.trust
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
      @katex ||= ExecJS.compile(File.read(@path_to_katex_js))
    end

    def base_options(display_mode)
      { displayMode: display_mode,
        macros: @global_macros,
        trust: @trust }
    end
  end
end
