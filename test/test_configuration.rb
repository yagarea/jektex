require 'test/unit'
require_relative '../lib/jektex/configuration'

class TestConfiguration < Test::Unit::TestCase

  def setup
    @test_jekyll_config = {
      "jektex" => {
        "cache_dir" => "TEST_CACHE_DIR",
        "ignore" => ["*.TEST_IGNORED_EXTENSION", "IGNORED_FILE.md"],
        "silent" => true,
        "katex_options" => {
          "trust" => true,
          "output" => "html",
          "displayMode" => true,
          "macros" => { "SMUGGLED" => "MACRO" },
          "throwOnError" => false,
          "globalGroup" => true
        },
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
    assert_equal(Hash.new, config.katex_options)
    assert_equal([".markdown", ".mkdown", ".mkdn", ".mkd", ".md"], config.markdown_extensions)
    assert_equal({
      '\jektex' => @jektex_logo_macro
    }, config.global_macros)
    assert_equal(0, config.number_of_global_macros)
    assert_equal(@jektex_logo_macro, config.global_macros['\jektex'])
    assert_equal([], config.warnings)
  end


  def test_load_jekyl_config
    config = Jektex::Config.new(@test_jekyll_config)

    # Should be changed by the test config
    assert_equal(File.join("TEST_CACHE_DIR", "jektex-cache.marshal"),
                 config.path_to_cache_file)
    assert_equal(["*.TEST_IGNORED_EXTENSION", "IGNORED_FILE.md", "TEST_CACHE_DIR/*"], config.ignore)
    assert_equal(true, config.silent)
    assert_equal(true, config.disable_disk_cache)

    # pass-through options survive, reserved keys are stripped with a warning
    assert_equal({ "trust" => true, "output" => "html" }, config.katex_options)
    assert_equal(4, config.warnings.size)
    assert_true(config.warnings.all? { |warning| warning.include?("controlled by jektex") })
    
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


  def test_markdown_extensions_from_config
    config = Jektex::Config.new({ "markdown_ext" => "md, MDX" })

    assert_equal([".md", ".mdx"], config.markdown_extensions)
  end


  def test_unknown_option_produces_warning
    config = Jektex::Config.new({ "jektex" => { "slient" => true } })

    assert_equal(1, config.warnings.size)
    assert_true(config.warnings.first.include?('unknown option "slient"'))
    assert_true(config.warnings.first.include?("cache_dir, ignore, silent, macros, katex_options"))
    assert_equal(false, config.silent)
  end


  def test_invalid_ignore_falls_back_to_default
    config = Jektex::Config.new({ "jektex" => { "ignore" => "*.xml" } })

    assert_true(config.warnings.first.include?('option "ignore" must be a list of file patterns'))
    assert_true(config.warnings.first.include?("falling back to default: []"))
    assert_equal([".jekyll-cache/*"], config.ignore)
  end


  def test_invalid_silent_falls_back_to_default
    config = Jektex::Config.new({ "jektex" => { "silent" => "yes" } })

    assert_true(config.warnings.first.include?("falling back to default: false"))
    assert_equal(false, config.silent)
  end


  def test_invalid_cache_dir_falls_back_to_default
    config = Jektex::Config.new({ "jektex" => { "cache_dir" => 13 } })

    assert_true(config.warnings.first.include?('falling back to default: ".jekyll-cache"'))
    assert_equal(File.join(".jekyll-cache", "jektex-cache.marshal"), config.path_to_cache_file)
  end


  def test_invalid_macros_fall_back_to_no_macros
    config = Jektex::Config.new({ "jektex" => { "macros" => { '\Q' => '\mathbb{Q}' } } })

    assert_true(config.warnings.first.include?("falling back to default: no macros"))
    assert_equal(0, config.number_of_global_macros)
  end


  def test_invalid_katex_options_fall_back_to_empty
    config = Jektex::Config.new({ "jektex" => { "katex_options" => "html" } })

    assert_true(config.warnings.first.include?("falling back to default: {}"))
    assert_equal(Hash.new, config.katex_options)
  end


  def test_non_mapping_jektex_section_is_ignored_with_warning
    config = Jektex::Config.new({ "jektex" => true })

    assert_true(config.warnings.first.include?("must be a mapping of options"))
    assert_equal(false, config.silent)
    assert_equal([".jekyll-cache/*"], config.ignore)
  end
end

