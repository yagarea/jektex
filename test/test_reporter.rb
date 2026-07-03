require_relative 'test_helper'
require 'jektex/configuration'
require 'jektex/reporter'

class TestReporter < Test::Unit::TestCase

  INDENT = " " * 13

  def setup
    @out = StringIO.new
    @reporter = Jektex::Reporter.new(build_config, out: @out)
  end


  def test_info_prints_indented_latex_line
    @reporter.info("hello")

    assert_equal("#{INDENT}LaTeX: hello\n", @out.string)
  end


  def test_macro_summary_with_no_macros
    @reporter.macro_summary(0, 0)

    assert_equal("#{INDENT}LaTeX: no macros loaded\n", @out.string)
  end


  def test_macro_summary_singular
    @reporter.macro_summary(1, 0)

    assert_equal("#{INDENT}LaTeX: 1 macro loaded\n", @out.string)
  end


  def test_macro_summary_plural
    @reporter.macro_summary(2, 0)

    assert_equal("#{INDENT}LaTeX: 2 macros loaded\n", @out.string)
  end


  def test_macro_summary_with_updated_macros
    @reporter.macro_summary(3, 2)

    assert_equal("#{INDENT}LaTeX: 3 macros loaded (2 updated)\n", @out.string)
  end


  def test_error_prints_red_message_with_document_path
    @reporter.error("ParseError: KaTeX parse error: Undefined control sequence", "_posts/a.md")

    assert_equal("\e[31m KaTeX parse error: Undefined control sequence\n\t_posts/a.md\e[0m\n",
                 @out.string)
  end


  def test_progress_overwrites_line_with_carriage_return
    @reporter.progress(3, 5)

    assert_equal("#{INDENT}LaTeX: 3 expressions rendered (5 loaded from cache)".ljust(72) + "\r",
                 @out.string)
  end


  def test_finish_ends_line_with_newline
    @reporter.finish(3, 5)

    assert_true(@out.string.end_with?("\r\n"))
    assert_true(@out.string.include?("3 expressions rendered (5 loaded from cache)"))
  end


  def test_silent_reporter_prints_nothing
    silent_out = StringIO.new
    silent_reporter = Jektex::Reporter.new(build_config("silent" => true), out: silent_out)

    silent_reporter.info("hello")
    silent_reporter.macro_summary(2, 1)
    silent_reporter.error("ParseError: x", "a.md")
    silent_reporter.progress(1, 2)
    silent_reporter.finish(1, 2)

    assert_equal("", silent_out.string)
  end
end
