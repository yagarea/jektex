module JekyllCustomPermalink
  autoload :VERSION, "jektex/version.rb"

  class CustomPermalinkError < StandardError; end
  class CustomPermalinkSetupError < CustomPermalinkError; end
end

require "jektex/jektex.rb"
