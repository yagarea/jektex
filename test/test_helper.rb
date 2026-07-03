$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require 'test/unit'
require 'stringio'
require 'tmpdir'

FakePage = Struct.new(:data, :content, :output, :relative_path)

def build_config(jektex_options = {}, top_level_options = {})
  require 'jektex/configuration'
  Jektex::Config.new(top_level_options.merge("jektex" => jektex_options))
end
