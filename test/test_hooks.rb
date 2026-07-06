require_relative 'test_helper'
require 'rbconfig'

# minimal Jekyll stand-in, defined BEFORE the gem is required,
# so that requiring the gem registers its hooks against it
module Jekyll
  module Hooks
    def self.registry
      @registry ||= Hash.new
    end

    def self.register(owners, event, &block)
      Array(owners).each { |owner| registry[[owner, event]] = block }
    end

    def self.trigger(owner, event, *args)
      registry[[owner, event]]&.call(*args)
    end
  end
end

require 'jektex'
# explicit, in case the entry point was already required without Jekyll
require 'jektex/hooks'

class TestHooks < Test::Unit::TestCase

  FakeSite = Struct.new(:config)

  MACROS = [['\RR', '\mathbb{R}'], ['\NN', '\mathbb{N}']]

  def setup
    @dir = Dir.mktmpdir
    reset_plugin_state
  end

  def teardown
    FileUtils.remove_entry(@dir)
    reset_plugin_state
  end

  def reset_plugin_state
    Jektex.config = nil
    Jektex.cache = nil
    Jektex.renderer = nil
    Jektex.page_processor = nil
    Jektex.reporter = nil
  end

  def site_config
    { "jektex" => { "cache_dir" => File.join(@dir, "cache"),
                    "macros" => MACROS } }
  end

  def trigger(owner, event, *args)
    Jekyll::Hooks.trigger(owner, event, *args)
  end

  # triggers an event while capturing everything the plugin prints;
  # a reporter constructed during the capture keeps writing to it afterwards
  def trigger_with_captured_output(owner, event, *args)
    captured = StringIO.new
    original_stdout = $stdout
    $stdout = captured
    begin
      trigger(owner, event, *args)
    ensure
      $stdout = original_stdout
    end
    captured
  end


  def test_hooks_are_registered_for_pages_and_documents
    [:pre_render, :post_render].each do |event|
      assert_not_nil(Jekyll::Hooks.registry[[:pages, event]])
      assert_same(Jekyll::Hooks.registry[[:pages, event]],
                  Jekyll::Hooks.registry[[:documents, event]])
    end
  end


  def test_after_reset_before_after_init_is_harmless
    # Site#initialize triggers one after_reset before after_init ever runs
    assert_nothing_raised { trigger(:site, :after_reset, FakeSite.new(site_config)) }
  end


  def test_full_build_lifecycle
    site = FakeSite.new(site_config)

    # true Jekyll order: reset fires first, then after_init
    trigger(:site, :after_reset, site)
    output = trigger_with_captured_output(:site, :after_init, site)

    assert_true(output.string.include?("2 macros loaded"))
    assert_false(output.string.include?("updated"))

    page = FakePage.new({}, 'intro \(\RR\) outro', nil, "post.md")
    trigger(:pages, :pre_render, page)
    # pre_render only protects math behind tokens; rendering happens post_render
    assert_match(Jektex::PageProcessor::TOKEN, page.content)
    assert_false(page.content.include?("katex"))
    page.output = page.content
    trigger(:pages, :post_render, page)
    assert_true(page.output.include?("katex"))

    document = FakePage.new({}, nil, 'converted \[x^2\]', "doc.md")
    trigger(:documents, :post_render, document)
    assert_true(document.output.include?("katex-display"))

    assert_equal(2, Jektex.page_processor.rendered_count)

    trigger(:site, :post_write, site)
    assert_true(File.exist?(Jektex.config.path_to_cache_file))
    assert_true(output.string.end_with?("\n"))

    # watch-mode rebuild: counters reset, same expression now comes from cache
    trigger(:site, :after_reset, site)
    assert_equal(0, Jektex.page_processor.rendered_count)
    rebuilt_page = FakePage.new({}, 'intro \(\RR\) outro', nil, "post.md")
    trigger(:pages, :pre_render, rebuilt_page)
    rebuilt_page.output = rebuilt_page.content
    trigger(:pages, :post_render, rebuilt_page)
    assert_equal(1, Jektex.page_processor.cache_hit_count)
    assert_equal(0, Jektex.page_processor.rendered_count)
  end


  def test_next_process_reuses_cache_and_macro_table
    site = FakeSite.new(site_config)
    trigger_with_captured_output(:site, :after_init, site)
    render_page_through_hooks('\(\RR\)')
    trigger(:site, :post_write, site)

    # simulate a completely new jekyll run against the same cache directory
    reset_plugin_state
    output = trigger_with_captured_output(:site, :after_init, site)

    # the persisted macro table matches, so nothing may be reported as updated
    assert_true(output.string.include?("2 macros loaded"))
    assert_false(output.string.include?("updated"))

    render_page_through_hooks('\(\RR\)')
    assert_equal(0, Jektex.page_processor.rendered_count)
    assert_equal(1, Jektex.page_processor.cache_hit_count)
  end

  def render_page_through_hooks(content)
    page = FakePage.new({}, content, nil, "post.md")
    trigger(:pages, :pre_render, page)
    page.output = page.content
    trigger(:pages, :post_render, page)
    page
  end


  def test_config_warnings_are_printed_at_startup
    site = FakeSite.new({ "jektex" => { "cache_dir" => File.join(@dir, "cache"),
                                        "slient" => true } })
    original_stderr = $stderr
    $stderr = StringIO.new
    begin
      trigger_with_captured_output(:site, :after_init, site)
      assert_true($stderr.string.include?('unknown option "slient"'))
    ensure
      $stderr = original_stderr
    end
  end


  def test_gem_loads_without_jekyll_in_a_clean_process
    lib_dir = File.expand_path("../lib", __dir__)

    assert_true(system(RbConfig.ruby, "-I", lib_dir, "-e", "require 'jektex'"))
  end
end
