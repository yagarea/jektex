# coding: utf-8

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "jekyll_custom_permalink/version"


Gem::Specification.new do |spec|
  spec.name        = "Jektex"
  spec.version     = JekyllCustomPermalink::VERSION
  spec.licenses    = ['GPLv3']
  spec.summary     = "Highly optimized latex rendering for Jekyll"
  spec.description = "Highly optimized and cached latex server side rendering for Jekyll with macros and dynamic output"
  spec.author      = ["Jan Černý"]
  spec.email       = "jc@ucw.cz"
  #spec.files      = ["lib/example.rb"]
  spec.files       = [*Dir["lib/**/*.rb"], "README.md", "LICENSE.md"]
  spec.test_files  = [*Dir["spec/*.rb"]]
  spec.homepage    = "https://github.com/yagarea/jektex"
  spec.metadata    = { "source_code_uri" => "https://github.com/yagarea/jektex" }
  spec.require_paths = ["lib"]


  if spec.respond_to?(:metadata)
    spec.metadata = {
        "bug_tracker_uri"   => "https://github.com/yagarea/jektex/issues",
        "documentation_uri" => "https://github.com/yagarea/jektex",
        "homepage_uri"      => "https://github.com/yagarea/jektex",
        "source_code_uri"   => "https://github.com/yagarea/jektex",
        "changelog_uri"     => "https://github.com/yagarea/jektex/blob/master/changelog.md"
    }
  end

  spec.required_ruby_version = ">= 1.9.3"
  spec.add_dependency "activesupport", ">= 6.1.4"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "bundler", "~> 1.6"

end
