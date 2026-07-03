require_relative 'test_helper'
require 'jektex/configuration'
require 'jektex/renderer'

class TestRenderer < Test::Unit::TestCase

  FakeRendererConfig = Struct.new(:path_to_katex_js, :global_macros, :trust)

  def setup
    @renderer = Jektex::Renderer.new(build_config)
  end


  def test_renders_inline_expression
    html = @renderer.render("x^2", display_mode: false)

    assert_true(html.include?("katex"))
    assert_false(html.include?("katex-display"))
  end


  def test_renders_display_expression
    html = @renderer.render("x^2", display_mode: true)

    assert_true(html.include?("katex-display"))
  end


  def test_expands_global_macros
    renderer = Jektex::Renderer.new(build_config("macros" => [['\RR', '\mathbb{R}']]))

    html = renderer.render('\RR', display_mode: false)

    assert_true(html.include?("mathbb"))
  end


  def test_renders_built_in_logo_macro
    html = @renderer.render('\jektex', display_mode: false)

    assert_true(html.include?("katex"))
  end


  def test_invalid_expression_raises_program_error
    error = assert_raise(ExecJS::ProgramError) do
      @renderer.render('\frac', display_mode: false)
    end

    assert_true(error.message.include?("ParseError"))
  end


  def test_error_fallback_renders_error_into_document
    html = @renderer.render_with_error_fallback('\frac', display_mode: false)

    assert_true(html.include?("katex-error"))
  end


  def test_trust_option_enables_href
    trusting = Jektex::Renderer.new(build_config("trust" => true))
    distrusting = Jektex::Renderer.new(build_config("trust" => false))
    expression = '\href{https://example.com}{link}'

    assert_true(trusting.render(expression, display_mode: false).include?("<a "))
    assert_false(distrusting.render(expression, display_mode: false).include?("<a "))
  end


  def test_katex_is_not_compiled_before_first_render
    renderer = Jektex::Renderer.new(
      FakeRendererConfig.new("/nonexistent/katex.min.js", Hash.new, false)
    )

    assert_raise(Errno::ENOENT) { renderer.render("x", display_mode: false) }
  end
end
