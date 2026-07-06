# Jekyll integration. Everything else in this gem is plain Ruby;
# this file is the only one that touches Jekyll::Hooks.

module Jektex
  class << self
    attr_accessor :config, :cache, :renderer, :page_processor, :reporter
  end
end

# Fires once per process (for jekyll build and jekyll serve alike),
# at the end of Site#initialize.
Jekyll::Hooks.register :site, :after_init do |site|
  Jektex.config    = Jektex::Config.new(site.config || Hash.new)
  Jektex.reporter  = Jektex::Reporter.new(Jektex.config)
  Jektex.cache     = Jektex::Cache.new(Jektex.config, reporter: Jektex.reporter).load
  Jektex.renderer  = Jektex::Renderer.new(Jektex.config)
  Jektex.page_processor = Jektex::PageProcessor.new(config: Jektex.config,
                                           cache: Jektex.cache,
                                           renderer: Jektex.renderer,
                                           reporter: Jektex.reporter)
  Jektex.reporter.macro_summary(Jektex.config.number_of_global_macros,
                                Jektex.cache.updated_global_macros.size)
end

# LaTeX notation (\( \) and \[ \]) in raw content, before Liquid/kramdown:
# expressions are protected behind inert tokens so markdown cannot touch them.
Jekyll::Hooks.register [:pages, :documents], :pre_render do |page|
  page.content = Jektex.page_processor.process_content(page)
end

# After conversion the HTML structure is known: tokens inside code markup
# are restored to their source text, everything else is rendered — including
# the \(..\)/\[..\] delimiters kramdown produces from its $$..$$ notation
# and the $$..$$ kramdown leaves untouched inside raw HTML blocks.
Jekyll::Hooks.register [:pages, :documents], :post_render do |page|
  page.output = Jektex.page_processor.process_output(page)
end

# Fires once per rebuild in watch mode — and also once during
# Site#initialize BEFORE after_init has run, hence the safe navigation.
Jekyll::Hooks.register :site, :after_reset do |_site|
  Jektex.page_processor&.reset_counters
end

Jekyll::Hooks.register :site, :post_write do |_site|
  # print stats once more so the error log cannot overwrite them
  Jektex.reporter.finish(Jektex.page_processor.rendered_count,
                         Jektex.page_processor.cache_hit_count)
  Jektex.cache.save
end
