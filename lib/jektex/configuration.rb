
class JektexConfig
  attr_reader :path_to_katex_js
  attr_reader :disable_disk_cache
  attr_reader :ignore
  attr_reader :console_indent
  attr_reader :silent
  attr_reader :front_matter_tag
  attr_reader :trust
  attr_reader :global_macros

  def initialize(config)
    @path_to_katex_js = File.join(__dir__, "/katex.min.js")

    @cache_dir = ".jekyll-cache"
    @cache_file = "jektex-cache.marshal"
    @disable_disk_cache = false

    @ignore = Array.new
    @console_indent = " " * 13
    @silent = false
    
    @front_matter_tag = "jektex"
    @trust = false
    
    @global_macros = Hash.new

    if config.is_a?(Hash)
      update_from_jekyll_config(config)
    end
    add_jektex_logo_macro
    @ignore.append("#{@cache_dir}/*")
  end

  def path_to_cache_file
    return File.join(@cache_dir, @cache_file)
  end

  def number_of_global_macros
    return @global_macros.length - 1
  end

  private
  def update_from_jekyll_config(config)
    if config.key?("jektex")
      jektex_config = config["jektex"]
      @cache_dir = jektex_config["cache_dir"] if jektex_config.key?("cache_dir")
      @ignore = jektex_config["ignore"] if jektex_config.key?("ignore")
      @silent = jektex_config["silent"] if jektex_config.key?("silent")
      @trust = jektex_config["trust"] if jektex_config.key?("trust")
      if jektex_config.has_key?("macros")
        for macro_definition in jektex_config["macros"]
          @global_macros[macro_definition[0]] = macro_definition[1]
        end
      end
    end

    @disable_disk_cache = config["disable_disk_cache"] if config.has_key?("disable_disk_cache")
  end

  def add_jektex_logo_macro
    @global_macros['\jektex'] =
      '\text{\raisebox{-0.55ex}{J}\kern{-0.3ex}E\kern{-0.25ex}\raisebox{-0.5ex}{K}\kern{-0.7ex}}\TeX'
  end

end
