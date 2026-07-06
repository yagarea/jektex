require_relative 'test_helper'
require 'jektex/cache'

class TestCache < Test::Unit::TestCase

  FakeCacheConfig = Struct.new(:path_to_cache_file, :path_to_katex_js,
                               :disable_disk_cache, :katex_options, :global_macros)

  class FakeReporter
    attr_reader :messages

    def initialize
      @messages = Array.new
    end

    def info(message)
      @messages.append(message)
    end
  end

  def setup
    @dir = Dir.mktmpdir
    @katex_js = File.join(@dir, "katex.min.js")
    File.write(@katex_js, "// katex stand-in")
    @cache_file = File.join(@dir, "cache", "jektex-cache.marshal")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def make_config(macros: {}, katex_options: {}, disable_disk_cache: false)
    FakeCacheConfig.new(@cache_file, @katex_js, disable_disk_cache, katex_options, macros)
  end

  def make_cache(reporter: nil, **config_options)
    Jektex::Cache.new(make_config(**config_options), reporter: reporter).load
  end


  def test_updated_macros_between_handles_nil_tables
    assert_equal([], Jektex::Cache.updated_macros_between(nil, nil))
    assert_equal(['\A'], Jektex::Cache.updated_macros_between({ '\A' => "1" }, nil))
    assert_equal(['\A'], Jektex::Cache.updated_macros_between(nil, { '\A' => "1" }))
  end


  def test_updated_macros_between_diffs_tables
    cached = { '\same' => "1", '\changed' => "old", '\removed' => "1" }
    current = { '\same' => "1", '\changed' => "new", '\added' => "1" }

    updated = Jektex::Cache.updated_macros_between(current, cached)

    assert_equal(['\changed', '\added', '\removed'].sort, updated.sort)
  end


  def test_fresh_cache_is_empty_with_no_updated_macros
    cache = make_cache(macros: { '\A' => "1" })

    assert_equal(0, cache.size)
    assert_equal([], cache.updated_global_macros)
  end


  def test_store_and_fetch_roundtrip
    cache = make_cache

    cache.store("x^2", false, "<span>html</span>")

    assert_equal("<span>html</span>", cache.fetch("x^2", false))
    assert_nil(cache.fetch("x^2", true))
    assert_nil(cache.fetch("y^2", false))
  end


  def test_display_and_inline_entries_are_independent
    cache = make_cache

    cache.store("x", false, "inline html")
    cache.store("x", true, "display html")

    assert_equal(2, cache.size)
    assert_equal("inline html", cache.fetch("x", false))
    assert_equal("display html", cache.fetch("x", true))
  end


  def test_save_and_load_preserves_entries_and_macros
    macros = { '\A' => "1" }
    cache = make_cache(macros: macros)
    cache.store("x", false, "html")
    cache.save

    reloaded = make_cache(macros: macros)

    assert_equal(1, reloaded.size)
    assert_equal("html", reloaded.fetch("x", false))
    assert_equal([], reloaded.updated_global_macros)
  end


  def test_save_creates_nested_cache_directory_without_temporary_residue
    cache = make_cache
    cache.save

    assert_true(File.exist?(@cache_file))
    assert_equal([], Dir.glob(File.join(@dir, "**", "*.tmp")))
  end


  def test_corrupt_cache_file_is_rebuilt_with_notice
    FileUtils.mkdir_p(File.dirname(@cache_file))
    File.write(@cache_file, "this is not marshal data")
    reporter = FakeReporter.new

    cache = make_cache(reporter: reporter)

    assert_equal(0, cache.size)
    assert_equal(["cache file is invalid and will be rebuilt"], reporter.messages)
  end


  def test_truncated_cache_file_is_rebuilt
    cache = make_cache
    cache.store("x", false, "html" * 100)
    cache.save
    valid_bytes = File.binread(@cache_file)
    File.binwrite(@cache_file, valid_bytes[0, valid_bytes.size / 2])

    assert_equal(0, make_cache.size)
  end


  def test_legacy_cache_format_is_rebuilt
    FileUtils.mkdir_p(File.dirname(@cache_file))
    legacy_payload = { Digest::SHA2.hexdigest("x") + "1" => "html",
                       "cached_global_macros" => { '\A' => "1" } }
    File.open(@cache_file, "wb") { |file| Marshal.dump(legacy_payload, file) }

    cache = make_cache

    assert_equal(0, cache.size)
    assert_equal([], cache.updated_global_macros)
  end


  def test_changing_katex_options_discards_cache
    cache = make_cache(katex_options: {})
    cache.store("x", false, "html")
    cache.save

    reporter = FakeReporter.new
    reloaded = make_cache(katex_options: { "trust" => true }, reporter: reporter)

    assert_equal(0, reloaded.size)
    assert_equal(["cache reset (configuration or KaTeX changed)"], reporter.messages)
  end


  def test_changing_katex_bundle_discards_cache
    cache = make_cache
    cache.store("x", false, "html")
    cache.save

    File.write(@katex_js, "// a different katex version")

    assert_equal(0, make_cache.size)
  end


  def test_macro_change_is_detected_on_load
    cache = make_cache(macros: { '\A' => "1", '\B' => "2" })
    cache.save

    reloaded = make_cache(macros: { '\A' => "1", '\B' => "3", '\C' => "4" })

    assert_equal(['\B', '\C'], reloaded.updated_global_macros.sort)
  end


  def test_fetch_misses_when_expression_contains_updated_macro
    cache = make_cache(macros: { '\B' => "2" })
    cache.store('\B + 1', false, "html")
    cache.store("unrelated", false, "html")
    cache.save

    reloaded = make_cache(macros: { '\B' => "3" })

    assert_nil(reloaded.fetch('\B + 1', false))
    assert_equal("html", reloaded.fetch("unrelated", false))
  end


  def test_disabled_disk_cache_saves_nothing
    cache = make_cache(disable_disk_cache: true)
    cache.store("x", false, "html")

    cache.save

    assert_false(File.exist?(@cache_file))
  end
end
