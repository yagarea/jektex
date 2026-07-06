require_relative 'test_helper'
require 'jektex/configuration'
require 'jektex/renderer'

class TestRenderer < Test::Unit::TestCase

  FakeRendererConfig = Struct.new(:path_to_katex_js, :global_macros, :katex_options)

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
    trusting = Jektex::Renderer.new(build_config("katex_options" => { "trust" => true }))
    distrusting = Jektex::Renderer.new(build_config)
    expression = '\href{https://example.com}{link}'

    assert_true(trusting.render(expression, display_mode: false).include?("<a "))
    assert_false(distrusting.render(expression, display_mode: false).include?("<a "))
  end


  def test_katex_options_are_passed_through
    default_output = @renderer.render("x^2", display_mode: false)
    html_only = Jektex::Renderer.new(build_config("katex_options" => { "output" => "html" }))

    result = html_only.render("x^2", display_mode: false)

    assert_true(default_output.include?("katex-mathml"))
    assert_false(result.include?("katex-mathml"))
    assert_true(result.include?("katex"))
  end


  def test_render_batch_renders_all_expressions_in_order
    results = @renderer.render_batch([["x^2", false], ["y^2", true], ["z^2", false]])

    assert_equal(3, results.size)
    assert_true(results.all? { |result| result.error.nil? })
    assert_true(results.all? { |result| result.html.include?("katex") })
    assert_false(results[0].html.include?("katex-display"))
    assert_true(results[1].html.include?("katex-display"))
  end


  def test_render_batch_isolates_errors_and_renders_fallback
    results = @renderer.render_batch([["x^2", false], ['\frac', false], ["y^2", false]])

    assert_nil(results[0].error)
    assert_not_nil(results[1].error)
    assert_true(results[1].error.include?("KaTeX parse error"))
    assert_true(results[1].html.include?("katex-error"))
    assert_nil(results[2].error)
    assert_true(results[2].html.include?("katex"))
  end


  def test_render_batch_with_no_expressions_makes_no_call
    renderer = Jektex::Renderer.new(
      FakeRendererConfig.new("/nonexistent/katex.min.js", Hash.new, Hash.new)
    )

    assert_equal([], renderer.render_batch([]))
  end


  def test_katex_is_not_compiled_before_first_render
    renderer = Jektex::Renderer.new(
      FakeRendererConfig.new("/nonexistent/katex.min.js", Hash.new, Hash.new)
    )

    assert_raise(Errno::ENOENT) { renderer.render("x", display_mode: false) }
  end
end
