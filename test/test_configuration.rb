require 'test/unit'
require_relative '../lib/jektex/configuration'

class TestConfiguration < Test::Unit::TestCase

  def setup
    @test_jekyll_config = {
      "jektex" => {
        "cache_dir" => "TEST_CACHE_DIR",
        "ignore" => ["*.TEST_IGNORED_EXTENSION", "IGNORED_FILE.md"],
        "silent" => true,
        "trust" => true,
        "macros" => [
          ['\TEST1', '\text{THIS IS A TEST MACRO}'],
          ['\TEST2', '\text{THIS IS A TEST MACRO TWO}'],
        ]
      },
      "disable_disk_cache" => true
    }
    @jektex_logo_macro = '\text{\raisebox{-0.55ex}{J}\kern{-0.3ex}E\kern{-0.25ex}\raisebox{-0.5ex}{K}\kern{-0.7ex}}\TeX'
  end


  def test_default_values
    config = Jektex::Config.new(Hash.new)

    assert_equal(File.join(".jekyll-cache", "jektex-cache.marshal"),
                 config.path_to_cache_file)
    assert_equal(false, config.disable_disk_cache)
    assert_equal([".jekyll-cache/*"], config.ignore)
    assert_equal(" " * 13, config.console_indent)
    assert_equal(false, config.silent)
    assert_equal("jektex", config.front_matter_tag)
    assert_equal(false, config.trust)
    assert_equal({
      '\jektex' => @jektex_logo_macro
    }, config.global_macros)
    assert_equal(0, config.number_of_global_macros)
    assert_equal(@jektex_logo_macro, config.global_macros['\jektex'])
  end


  def test_load_jekyl_config
    config = Jektex::Config.new(@test_jekyll_config)

    # Should be changed by the test config
    assert_equal(File.join("TEST_CACHE_DIR", "jektex-cache.marshal"),
                 config.path_to_cache_file)
    assert_equal(["*.TEST_IGNORED_EXTENSION", "IGNORED_FILE.md", "TEST_CACHE_DIR/*"], config.ignore)
    assert_equal(true, config.silent)
    assert_equal(true, config.trust)
    assert_equal(true, config.disable_disk_cache)
    
    assert_equal({
      '\TEST1' => '\text{THIS IS A TEST MACRO}',
      '\TEST2' => '\text{THIS IS A TEST MACRO TWO}',
      '\jektex' => @jektex_logo_macro
    }, config.global_macros)
    assert_equal(2, config.number_of_global_macros)

    # Should not be changed by the test config
    assert_equal(" " * 13, config.console_indent)
    assert_equal("jektex", config.front_matter_tag)
  end
end

