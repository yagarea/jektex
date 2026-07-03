module Jektex
  # All console output of the plugin. Every method is a no-op when the
  # silent option is set, so callers never have to check it themselves.
  class Reporter
    def initialize(config, out: $stdout)
      @out = out
      @silent = config.silent
      @indent = config.console_indent
      @last_progress_time = nil
    end

    def info(message)
      return if @silent
      @out.puts "#{@indent}LaTeX: #{message}"
    end

    def macro_summary(macro_count, updated_count)
      return if @silent
      if macro_count == 0
        info("no macros loaded")
      else
        message = "#{macro_count} macro#{macro_count == 1 ? "" : "s"} loaded"
        message += " (#{updated_count} updated)" if updated_count > 0
        info(message)
      end
    end

    def error(message, doc_path)
      return if @silent
      @out.puts "\e[31m #{message.gsub("ParseError: ", "")}\n\t#{doc_path}\e[0m"
    end

    # more frequent updates than this are invisible anyway, and printing
    # one per expression measurably slows down large cached builds
    PROGRESS_UPDATE_INTERVAL = 0.1

    def progress(rendered, from_cache)
      return if @silent
      now = Time.now
      return if @last_progress_time && now - @last_progress_time < PROGRESS_UPDATE_INTERVAL
      @last_progress_time = now
      print_progress_line(rendered, from_cache)
    end

    def finish(rendered, from_cache)
      return if @silent
      print_progress_line(rendered, from_cache)
      @out.print "\n"
    end

    private

    # single line overwritten in place with a carriage return;
    # padded to a fixed width so a shorter update fully covers the previous one
    def print_progress_line(rendered, from_cache)
      line = "#{@indent}LaTeX: #{rendered} expressions rendered (#{from_cache} loaded from cache)"
      @out.print line.ljust(72) + "\r"
      @out.flush
    end
  end
end
