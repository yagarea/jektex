require "jektex/version"
require "jektex/configuration"
require "jektex/reporter"
require "jektex/renderer"
require "jektex/cache"
require "jektex/page_processor"

# when loaded as a Jekyll plugin, Jekyll is always defined; the guard
# lets the gem be required standalone (for tests and other tooling)
require "jektex/hooks" if defined?(Jekyll)
