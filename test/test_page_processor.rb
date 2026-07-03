require_relative 'test_helper'
require 'jektex/configuration'
require 'jektex/reporter'
require 'jektex/renderer'
require 'jektex/cache'
require 'jektex/page_processor'

class TestPageProcessor < Test::Unit::TestCase

  class InterruptingRenderer
    def render(_expression, display_mode:)
      raise Interrupt
    end
  end

  class RecordingRenderer
    attr_reader :expressions

    def initialize
      @expressions = Array.new
    end

    def render(expression, display_mode:)
      @expressions.append(expression)
      return "[rendered]"
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
    Jektex::PageProcessor.new(config: config, cache: @cache, renderer: renderer, reporter: reporter)
  end

  def make_page(content, data: {}, path: "post.md")
    FakePage.new(data, content, content, path)
  end


  def test_renders_inline_math_in_content
    page = make_page('before \(x^2\) after')

    result = make_processor.process(page, :content)

    assert_true(result.include?("katex"))
    assert_true(result.start_with?("before "))
    assert_true(result.end_with?(" after"))
    assert_false(result.include?('\(x^2\)'))
  end


  def test_renders_display_math_in_output
    page = make_page('\[x^2\]')

    result = make_processor.process(page, :output)

    assert_true(result.include?("katex-display"))
  end


  def test_renders_multiline_expression
    page = make_page("\\(a\n+ b\\)")

    result = make_processor.process(page, :content)

    assert_true(result.include?("katex"))
  end


  def test_renders_multiple_expressions_on_one_line
    processor = make_processor
    page = make_page('\(a\) and \(b\)')

    result = processor.process(page, :content)

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


  def test_decoded_entities_share_cache_entry_with_plain_characters
    processor = make_processor
    processor.process(make_page('\(1 &gt; 0\)'), :content)
    processor.process(make_page('\(1 > 0\)'), :content)

    assert_equal(1, processor.rendered_count)
    assert_equal(1, processor.cache_hit_count)
  end


  def test_counters_separate_renders_from_cache_hits
    processor = make_processor
    processor.process(make_page('\(a\) \(b\) \(a\)'), :content)

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
    first_build.process(make_page('\(\RR\)'), :content)
    @cache.save

    second_build = make_processor({ "macros" => macros_after })
    second_build.process(make_page('\(\RR\)'), :content)

    assert_equal(1, second_build.rendered_count)
    assert_equal(0, second_build.cache_hit_count)
  end


  def test_ignores_page_with_front_matter_flag
    processor = make_processor

    [false, "false"].each do |flag|
      page = make_page('\(x\)', data: { "jektex" => flag })
      assert_true(processor.ignored?(page))
      assert_equal('\(x\)', processor.process(page, :content))
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

    assert_same(original, processor.process(page, :content))
  end


  def test_ignored_page_returns_original_object
    processor = make_processor
    original = '\(x\)'.freeze
    page = FakePage.new({ "jektex" => false }, original, original, "post.md")

    assert_same(original, processor.process(page, :content))
  end


  def test_invalid_expression_renders_error_and_reports_it
    out = StringIO.new
    processor = make_processor(out: out)
    page = make_page('\(\frac\)', path: "_posts/broken.md")

    result = processor.process(page, :content)

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
