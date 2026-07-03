require 'digest'
require 'fileutils'

module Jektex
  # Disk cache of rendered expressions. The cache file additionally stores
  # the macro table it was rendered with, so expressions using an edited
  # macro can be invalidated individually, and a fingerprint of everything
  # else that affects KaTeX output, so a KaTeX or configuration change
  # discards the whole cache instead of serving stale HTML.
  class Cache
    FORMAT = 2

    attr_reader :updated_global_macros

    # names of macros whose definition differs between the two tables
    def self.updated_macros_between(current_macros, cached_macros)
      current = current_macros || Hash.new
      cached = cached_macros || Hash.new
      (current.keys | cached.keys).reject { |name| current[name] == cached[name] }
    end

    def initialize(config, reporter: nil)
      @config = config
      @reporter = reporter
      @entries = Hash.new
      @updated_global_macros = Array.new
    end

    def load
      payload = read_payload
      if payload
        @entries = payload["entries"]
        @updated_global_macros =
          self.class.updated_macros_between(@config.global_macros, payload["macros"])
      end
      return self
    end

    def fetch(expression, display_mode)
      return nil if @updated_global_macros.any? { |macro| expression.include?(macro) }
      return @entries[key_for(expression, display_mode)]
    end

    def store(expression, display_mode, html)
      @entries[key_for(expression, display_mode)] = html
    end

    def size
      return @entries.size
    end

    def save
      return if @config.disable_disk_cache
      path = @config.path_to_cache_file
      FileUtils.mkdir_p(File.dirname(path))
      payload = { "format" => FORMAT,
                  "fingerprint" => fingerprint,
                  "macros" => @config.global_macros,
                  "entries" => @entries }
      # write to a temporary file first so an interrupted write
      # can never leave a truncated cache behind
      temporary_path = path + ".tmp"
      File.open(temporary_path, "wb") { |file| Marshal.dump(payload, file) }
      File.rename(temporary_path, path)
    end

    private

    def read_payload
      path = @config.path_to_cache_file
      return nil unless File.exist?(path)
      payload = File.open(path, "rb") { |file| Marshal.load(file) }
      unless valid?(payload)
        @reporter&.info("cache file is invalid and will be rebuilt")
        return nil
      end
      unless payload["fingerprint"] == fingerprint
        @reporter&.info("cache reset (configuration or KaTeX changed)")
        return nil
      end
      return payload
    rescue StandardError
      @reporter&.info("cache file is invalid and will be rebuilt")
      return nil
    end

    def valid?(payload)
      payload.is_a?(Hash) &&
        payload["format"] == FORMAT &&
        payload["entries"].is_a?(Hash) &&
        payload["macros"].is_a?(Hash)
    end

    def key_for(expression, display_mode)
      Digest::SHA2.hexdigest(expression) + (display_mode ? ":display" : ":inline")
    end

    # every config option that changes KaTeX output (except macros, which
    # are diffed individually) must be part of this fingerprint
    def fingerprint
      @fingerprint ||= [FORMAT,
                        Digest::SHA2.file(@config.path_to_katex_js).hexdigest[0, 16],
                        "trust=#{@config.trust}"].join("|")
    end
  end
end
