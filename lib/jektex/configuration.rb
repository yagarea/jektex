module Jektex
  class Config
    # KaTeX options jektex needs to control itself: displayMode is decided
    # per expression by its delimiters, macros have their own config key,
    # throwOnError drives the error reporting pipeline, and globalGroup
    # would make rendering order-dependent, which breaks caching
    RESERVED_KATEX_OPTIONS = ["displayMode", "macros", "throwOnError", "globalGroup"].freeze

    KNOWN_OPTIONS = ["cache_dir", "ignore", "silent", "macros", "katex_options"].freeze

    attr_reader :path_to_katex_js
    attr_reader :disable_disk_cache
    attr_reader :ignore
    attr_reader :console_indent
    attr_reader :silent
    attr_reader :front_matter_tag
    attr_reader :katex_options
    attr_reader :global_macros
    attr_reader :markdown_extensions
    # problems found while reading the configuration; the plugin prints
    # them at startup, so this class can stay free of console output
    attr_reader :warnings

    def initialize(config)
      @path_to_katex_js = File.join(__dir__, "/katex.min.js")

      @cache_dir = ".jekyll-cache"
      @cache_file = "jektex-cache.marshal"
      @disable_disk_cache = false

      @ignore = Array.new
      @console_indent = " " * 13
      @silent = false

      @front_matter_tag = "jektex"
      @katex_options = Hash.new

      @markdown_ext = "markdown,mkdown,mkdn,mkd,md"

      @global_macros = Hash.new
      @warnings = Array.new

      if config.is_a?(Hash)
        update_from_jekyll_config(config)
      end
      add_jektex_logo_macro
      @ignore.append("#{@cache_dir}/*")
      @markdown_extensions = @markdown_ext.to_s.split(",").map { |ext| ".#{ext.strip.downcase}" }
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
        if jektex_config.is_a?(Hash)
          warn_about_unknown_options(jektex_config)
          @cache_dir = checked_option(jektex_config, "cache_dir", @cache_dir, "a string") do |value|
            value.is_a?(String)
          end
          @ignore = checked_option(jektex_config, "ignore", @ignore, "a list of file patterns") do |value|
            value.is_a?(Array) && value.all? { |pattern| pattern.is_a?(String) }
          end
          @silent = checked_option(jektex_config, "silent", @silent, "true or false") do |value|
            value == true || value == false
          end
          read_katex_options(jektex_config)
          read_macros(jektex_config)
        else
          @warnings.append('the "jektex" configuration must be a mapping of options, ignoring it')
        end
      end

      @disable_disk_cache = config["disable_disk_cache"] if config.has_key?("disable_disk_cache")
      @markdown_ext = config["markdown_ext"] if config.has_key?("markdown_ext")
    end

    def warn_about_unknown_options(jektex_config)
      jektex_config.each_key do |key|
        next if KNOWN_OPTIONS.include?(key)
        @warnings.append("unknown option \"#{key}\" " \
                         "(known options: #{KNOWN_OPTIONS.join(", ")})")
      end
    end

    # returns the configured value when the validation block accepts it,
    # otherwise warns, names the default and returns it
    def checked_option(jektex_config, name, default, expectation)
      return default unless jektex_config.key?(name)
      value = jektex_config[name]
      return value if yield(value)
      @warnings.append("option \"#{name}\" must be #{expectation}, " \
                       "falling back to default: #{default.inspect}")
      return default
    end

    def read_katex_options(jektex_config)
      return unless jektex_config.key?("katex_options")
      options = jektex_config["katex_options"]
      unless options.is_a?(Hash)
        @warnings.append('option "katex_options" must be a mapping of KaTeX options, ' \
                         "falling back to default: {}")
        return
      end
      options.each_key do |key|
        if RESERVED_KATEX_OPTIONS.include?(key.to_s)
          @warnings.append("KaTeX option \"#{key}\" is controlled by jektex and was ignored")
        end
      end
      @katex_options = options.reject { |key, _value| RESERVED_KATEX_OPTIONS.include?(key.to_s) }
    end

    def read_macros(jektex_config)
      return unless jektex_config.has_key?("macros")
      macro_list = jektex_config["macros"]
      valid = macro_list.is_a?(Array) && macro_list.all? do |pair|
        pair.is_a?(Array) && pair.size == 2 && pair.all? { |part| part.is_a?(String) }
      end
      unless valid
        @warnings.append('option "macros" must be a list of [name, definition] pairs of strings, ' \
                         "falling back to default: no macros")
        return
      end
      for macro_definition in macro_list
        @global_macros[macro_definition[0]] = macro_definition[1]
      end
    end

    def add_jektex_logo_macro
      @global_macros['\jektex'] =
        '\text{\raisebox{-0.55ex}{J}\kern{-0.3ex}E\kern{-0.25ex}\raisebox{-0.5ex}{K}\kern{-0.7ex}}\TeX'
    end

  end
end
