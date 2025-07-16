
#PHONY: local

local:
	rm -rf ./jektex-*.gem
	gem build jektex.gemspec
	gem uninstall jektex
	gem install ./jektex-*.gem

run-tests:
	@echo "Test testing"
	ruby -Itest test/test_configuration.rb
