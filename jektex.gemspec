# coding: utf-8

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "jektex/version"

Gem::Specification.new do |spec|
  spec.name          = "jektex"
  spec.version       = Jektex::VERSION
  spec.licenses      = ["GPL-3.0-or-later"]
  spec.summary       = "Highly optimized latex rendering for Jekyll"
  spec.description   = "Highly optimized and cached latex server side rendering for Jekyll with macros and dynamic output"
  spec.author        = ["Jan Černý"]
  spec.email         = "jc@ucw.cz"
  spec.files         = [*Dir["lib/**/*.rb"], *Dir["lib/**/*.js"], "README.md", "LICENSE"]
  spec.test_files    = [*Dir["spec/*.rb"]]
  spec.homepage      = "https://github.com/yagarea/jektex"
  spec.metadata      = { "source_code_uri" => "https://github.com/yagarea/jektex" }
  spec.require_paths = ["lib"]

  if spec.respond_to?(:metadata)
    spec.metadata = {
        "bug_tracker_uri"   => "https://github.com/yagarea/jektex/issues",
        "documentation_uri" => "https://github.com/yagarea/jektex/blob/master/README.md",
        "homepage_uri"      => "https://github.com/yagarea/jektex",
        "source_code_uri"   => "https://github.com/yagarea/jektex",
        "changelog_uri"     => "https://github.com/yagarea/jektex/blob/master/changelog.md"
    }
  end

  spec.required_ruby_version = ">= 2.7.0"
  spec.add_dependency "execjs", "~> 2.1", ">= 2.9.1"
  spec.add_dependency "digest", "~> 3.1.1", ">= 3.1.1"
  spec.add_dependency "htmlentities", "~> 4.3", ">= 4.3.4"
  spec.add_development_dependency "bundler", "~> 2.0", ">= 2.0.0"

end
