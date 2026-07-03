require_relative 'test_helper'
require 'jektex/configuration'
require 'jektex/reporter'
require 'jektex/renderer'
require 'jektex/cache'
require 'jektex/page_processor'

class TestPageProcessor < Test::Unit::TestCase

  TOKEN = Jektex::PageProcessor::TOKEN

  class InterruptingRenderer
    def render_batch(_expressions)
      raise Interrupt
    end
  end

  class RecordingRenderer
    attr_reader :expressions, :batch_calls

    def initialize
      @expressions = Array.new
      @batch_calls = 0
    end

    def render_batch(expressions)
      @batch_calls += 1
      @expressions.concat(expressions.map { |expression, _mode| expression })
      return expressions.map { Jektex::Renderer::RenderedExpression.new("[rendered]", nil) }
    end
  end

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def make_processor(jektex_options = {}, top_level_options = {}, out: StringIO.new)
    config = build_config({ "cache_dir" => File.join(@dir, "cache") }.merge(jektex_options),
                          top_level_options)
    reporter = Jektex::Reporter.new(config, out: out)
    @cache = Jektex::Cache.new(config, reporter: reporter).load
    renderer = Jektex::Renderer.new(config)
    Jektex::PageProcessor.new(config: config, cache: @cache,
                              renderer: renderer, reporter: reporter)
  end

  def make_page(content, data: {}, path: "post.md")
    FakePage.new(data, content, content, path)
  end


  ##### protection of LaTeX notation (pre_render + post_render pipeline)

  def test_content_math_is_protected_behind_tokens
    processor = make_processor
    page = make_page('before \(x^2\) after')

    content = processor.process_content(page)

    assert_match(TOKEN, content)
    assert_false(content.include?("katex"))
    assert_false(content.include?('\('))
    assert_equal(0, processor.rendered_count)
  end


  def test_protected_math_renders_in_plain_output
    processor = make_processor
    page = make_page('before \(x^2\) after')
    page.output = processor.process_content(page)

    result = processor.process_output(page)

    assert_true(result.include?("katex"))
    assert_true(result.start_with?("before "))
    assert_true(result.end_with?(" after"))
    assert_no_match(TOKEN, result)
    assert_equal(1, processor.rendered_count)
  end


  def test_protected_display_math_keeps_display_mode
    processor = make_processor
    page = make_page('\[x^2\]')
    page.output = processor.process_content(page)

    result = processor.process_output(page)

    assert_true(result.include?("katex-display"))
  end


  def test_math_inside_code_block_is_restored_as_source
    processor = make_processor
    page = make_page('\(x^2\)')
    token = processor.process_content(page)
    page.output = "<p>doc</p><pre><code>#{token}</code></pre>"

    result = processor.process_output(page)

    assert_equal('<p>doc</p><pre><code>\(x^2\)</code></pre>', result)
    assert_equal(0, processor.rendered_count)
    assert_equal(0, @cache.size)
  end


  def test_same_expression_renders_in_text_but_not_in_code
    processor = make_processor
    page = make_page('\(x^2\)')
    token = processor.process_content(page)
    page.output = "<p>#{token}</p><code>#{token}</code>"

    result = processor.process_output(page)

    assert_true(result.include?("katex"))
    assert_true(result.include?('<code>\(x^2\)</code>'))
    assert_equal(1, processor.rendered_count)
  end


  def test_kramdown_notation_inside_code_stays_literal
    processor = make_processor
    page = make_page(nil)
    page.output = 'see <code>\(x\)</code> and <pre>\[y\]</pre> for syntax'

    result = processor.process_output(page)

    assert_equal('see <code>\(x\)</code> and <pre>\[y\]</pre> for syntax', result)
    assert_equal(0, processor.rendered_count)
  end


  def test_script_and_style_contents_are_untouched
    processor = make_processor
    page = make_page(nil)
    page.output = '<script>var m = "\(x\)";</script><style>.a::before{content:"\[y\]"}</style>'

    result = processor.process_output(page)

    assert_equal(page.output, result)
    assert_equal(0, processor.rendered_count)
  end


  def test_token_shaped_text_without_registration_is_left_alone
    processor = make_processor
    page = make_page(nil)
    page.output = "<p>jektexprotected#{"a" * 32}</p>"

    assert_equal(page.output, processor.process_output(page))
  end


  ##### kramdown notation in converted output (immediate rendering)

  def test_renders_display_math_in_output
    page = make_page('\[x^2\]')

    result = make_processor.process_output(page)

    assert_true(result.include?("katex-display"))
  end


  def test_renders_multiline_expression
    page = make_page("\\(a\n+ b\\)")

    result = make_processor.process_output(page)

    assert_true(result.include?("katex"))
  end


  def test_renders_multiple_expressions_on_one_line
    processor = make_processor
    page = make_page('\(a\) and \(b\)')

    result = processor.process_output(page)

    assert_true(result.include?(" and "))
    assert_equal(2, processor.rendered_count)
    assert_equal(2, @cache.size)
  end


  def test_escaped_closing_delimiter_stays_inside_expression
    config = build_config("cache_dir" => File.join(@dir, "cache"))
    renderer = RecordingRenderer.new
    processor = Jektex::PageProcessor.new(config: config,
                                          cache: Jektex::Cache.new(config).load,
                                          renderer: renderer,
                                          reporter: Jektex::Reporter.new(config, out: StringIO.new))

    # the middle \) is escaped as \\), so the expression runs to the final \)
    result = processor.render_math('\(a\\\\) b\) after', "post.md")

    assert_equal(['a\\\\) b'], renderer.expressions)
    assert_equal("[rendered] after", result)
  end


  def test_mathless_page_skips_scanning_and_rendering
    config = build_config("cache_dir" => File.join(@dir, "cache"))
    renderer = RecordingRenderer.new
    processor = Jektex::PageProcessor.new(config: config,
                                          cache: Jektex::Cache.new(config).load,
                                          renderer: renderer,
                                          reporter: Jektex::Reporter.new(config, out: StringIO.new))
    page = make_page("just text, no math at all")

    assert_equal("just text, no math at all", processor.process_output(page))
    assert_same(page.content, processor.process_content(page))
    assert_equal(0, renderer.batch_calls)
  end


  def test_identical_page_across_builds_is_answered_from_cache
    body = 'x \(a\) y \[b\] z'
    first_build = make_processor
    first_result = first_build.process_output(make_page(body))
    assert_equal(2, first_build.rendered_count)
    @cache.save

    second_build = make_processor
    result = second_build.process_output(make_page(body))

    assert_equal(first_result, result)
    assert_equal(2, second_build.cache_hit_count)
    assert_equal(0, second_build.rendered_count)
  end


  def test_page_with_render_error_is_rescanned_every_build
    out = StringIO.new
    processor = make_processor(out: out)

    first_result = processor.process_output(make_page('\(\frac\)'))
    second_result = processor.process_output(make_page('\(\frac\)'))

    assert_equal(first_result, second_result)
    assert_equal(2, out.string.scan("\e[31m").size)
  end


  def test_page_needs_a_single_batched_render_call
    config = build_config("cache_dir" => File.join(@dir, "cache"))
    renderer = RecordingRenderer.new
    processor = Jektex::PageProcessor.new(config: config,
                                          cache: Jektex::Cache.new(config).load,
                                          renderer: renderer,
                                          reporter: Jektex::Reporter.new(config, out: StringIO.new))
    page = make_page('\(a\) text \[b\] text \(c\) and \(a\) again')

    processor.process_output(page)

    assert_equal(1, renderer.batch_calls)
    assert_equal(["a", "b", "c"], renderer.expressions.sort)
  end


  def test_decoded_entities_share_cache_entry_with_plain_characters
    processor = make_processor
    processor.process_output(make_page('\(1 &gt; 0\)'))
    processor.process_output(make_page('\(1 > 0\)'))

    assert_equal(1, processor.rendered_count)
    assert_equal(1, processor.cache_hit_count)
  end


  def test_counters_separate_renders_from_cache_hits
    processor = make_processor
    processor.process_output(make_page('\(a\) \(b\) \(a\)'))

    assert_equal(2, processor.rendered_count)
    assert_equal(1, processor.cache_hit_count)

    processor.reset_counters

    assert_equal(0, processor.rendered_count)
    assert_equal(0, processor.cache_hit_count)
  end


  def test_expression_with_updated_macro_is_rerendered
    macros_before = [['\RR', '\mathbb{R}']]
    macros_after = [['\RR', '\mathbb{Q}']]

    first_build = make_processor({ "macros" => macros_before })
    first_build.process_output(make_page('\(\RR\)'))
    @cache.save

    second_build = make_processor({ "macros" => macros_after })
    second_build.process_output(make_page('\(\RR\)'))

    assert_equal(1, second_build.rendered_count)
    assert_equal(0, second_build.cache_hit_count)
  end


  ##### ignore rules

  def test_ignores_page_with_front_matter_flag
    processor = make_processor

    [false, "false"].each do |flag|
      page = make_page('\(x\)', data: { "jektex" => flag })
      assert_true(processor.ignored?(page))
      assert_equal('\(x\)', processor.process_content(page))
      assert_equal('\(x\)', processor.process_output(page))
    end

    [true, nil].each do |flag|
      page = make_page('\(x\)', data: { "jektex" => flag })
      assert_false(processor.ignored?(page))
    end
  end


  def test_ignores_pages_matching_patterns
    processor = make_processor({ "ignore" => ["*.xml", "_drafts/*"] })

    assert_true(processor.ignored?(make_page("", path: "feed.xml")))
    assert_true(processor.ignored?(make_page("", path: "_drafts/a.md")))
    assert_false(processor.ignored?(make_page("", path: "_posts/a.md")))
  end


  def test_ignores_cache_directory_by_default
    config = Jektex::Config.new(Hash.new)
    processor = Jektex::PageProcessor.new(config: config, cache: nil,
                                          renderer: nil, reporter: nil)

    assert_true(config.ignore.include?(".jekyll-cache/*"))
    page = make_page("", path: ".jekyll-cache/jektex-cache.marshal")
    assert_true(processor.ignored?(page))
  end


  def test_page_without_data_is_returned_untouched
    processor = make_processor
    original = '\(x\)'.freeze
    page = FakePage.new(nil, original, original, "post.md")

    assert_same(original, processor.process_content(page))
    assert_same(original, processor.process_output(page))
  end


  def test_ignored_page_returns_original_object
    processor = make_processor
    original = '\(x\)'.freeze
    page = FakePage.new({ "jektex" => false }, original, original, "post.md")

    assert_same(original, processor.process_content(page))
    assert_same(original, processor.process_output(page))
  end


  ##### error and interrupt paths

  def test_invalid_expression_renders_error_and_reports_it
    out = StringIO.new
    processor = make_processor(out: out)
    page = make_page('\(\frac\)', path: "_posts/broken.md")

    result = processor.process_output(page)

    assert_true(result.include?("katex-error"))
    assert_true(out.string.include?("\e[31m"))
    assert_true(out.string.include?("_posts/broken.md"))
    assert_equal(0, processor.rendered_count)
    assert_equal(0, @cache.size)
  end


  def test_interrupt_during_render_saves_cache_and_reraises
    config = build_config("cache_dir" => File.join(@dir, "cache"))
    cache = Jektex::Cache.new(config).load
    processor = Jektex::PageProcessor.new(config: config, cache: cache,
                                          renderer: InterruptingRenderer.new,
                                          reporter: Jektex::Reporter.new(config, out: StringIO.new))

    assert_raise(Interrupt) { processor.render_math('\(x\)', "post.md") }
    assert_true(File.exist?(config.path_to_cache_file))
  end


  def test_interrupt_respects_disabled_disk_cache
    config = build_config({ "cache_dir" => File.join(@dir, "cache") },
                          { "disable_disk_cache" => true })
    cache = Jektex::Cache.new(config).load
    processor = Jektex::PageProcessor.new(config: config, cache: cache,
                                          renderer: InterruptingRenderer.new,
                                          reporter: Jektex::Reporter.new(config, out: StringIO.new))

    assert_raise(Interrupt) { processor.render_math('\(x\)', "post.md") }
    assert_false(File.exist?(config.path_to_cache_file))
  end
end
