require 'execjs'
require 'digest'
require 'htmlentities'


PATH_TO_JS = File.join(__dir__, "/katex.min.js")
DEFAULT_CACHE_DIR = ".jekyll-cache"
CACHE_FILE = "jektex-cache.marshal"
KATEX = ExecJS.compile(open(PATH_TO_JS).read)
PARSE_ERROR_PLACEHOLDER = "<b style='color: red;'>PARSE ERROR</b>"
FRONT_MATTER_TAG = "jektex"

$global_macros = Hash.new
$updated_global_macros = Array.new

$count_newly_generated_expressions = 0

$path_to_cache = File.join(DEFAULT_CACHE_DIR, CACHE_FILE)
$cache = nil
$disable_disk_cache = false

$ignored = Array.new

def get_list_of_updated_global_macros(current_macros, cached_global_macros)
  return Array.new if cached_global_macros.nil? && current_macros.nil?
  return current_macros.keys if cached_global_macros.nil?
  return cached_global_macros.keys if current_macros.nil?

  macro_set = Set.new(cached_global_macros.keys + current_macros.keys)
  macro_set.delete_if { |m| cached_global_macros[m] == current_macros[m] }
  return macro_set.to_a
end

def is_ignored?(page)
  for patern in $ignored
    return true if File.fnmatch?(patern, page.relative_path, File::FNM_DOTMATCH)
  end
  return false
end

def contains_updated_global_macro?(expression)
  for m in $updated_global_macros
    return true if expression[m]
  end
  return false
end

def print_stats
  indent = " " * 13
  print "#{indent}LaTeX: " \
  "#{$count_newly_generated_expressions} expressions rendered " \
  "(#{$cache.size} already cached)".ljust(72) + "\r"
  $stdout.flush
end

def render(page)
  # check if document is not set to be ignored
  return page.output if page.data == nil or is_ignored?(page) or page.data[FRONT_MATTER_TAG] == "false"
  # convert HTML entities back to characters
  post = HTMLEntities.new.decode(page.output.to_s)
  # render inline expressions
  post = post.gsub(/(\\\()((.|\n)*?)(?<!\\)\\\)/) { |m| escape_method($1, $2, page.relative_path) }
  # render display expressions
  post = post.gsub(/(\\\[)((.|\n)*?)(?<!\\)\\\]/) { |m| escape_method($1, $2, page.relative_path) }
  return post
end

def escape_method( type, string, doc_path )
  # detect if expression is display view
  @display = type.downcase =~ /\[/

  # generate a hash from the math expression
  @expression_hash = Digest::SHA2.hexdigest(string) + @display.to_s

  # use it if it exists
  if($cache.has_key?(@expression_hash) && !contains_updated_global_macro?(string)) then
    # check if expressin conains updated macro
    $count_newly_generated_expressions += 1
    print_stats
    return $cache[@expression_hash]

  # else generate one and store it
  else
    # create the cache directory, if it doesn't exist
    begin
      # render using ExecJS
      @result =  KATEX.call("katex.renderToString", string,
                          {displayMode: @display,  macros: $global_macros})
    rescue SystemExit, Interrupt
      # save cache to disk
      File.open($path_to_cache, "w"){|to_file| Marshal.dump($cache, to_file)}
      # this stops jekyll being immune to interrupts and kill command
      raise
    rescue ExecJS::ProgramError => pe
      # catch parse error
      puts "\e[31m " + pe.message.gsub("ParseError: ", "") + "\n\t"  + doc_path + "\e[0m"
      return PARSE_ERROR_PLACEHOLDER
    end
    # save to cache
    $cache[@expression_hash] = @result
    # update count of newly generated expressions
    $count_newly_generated_expressions += 1
    print_stats
    return @result
  end
end

Jekyll::Hooks.register :pages, :post_render do |page|
  page.output = render(page)
end

Jekyll::Hooks.register :documents, :post_render do |doc|
  doc.output = render(doc)
end

Jekyll::Hooks.register :site, :after_init do |site|
  # load jektex config from config file and if no config is defined make empty one
  config = site.config["jektex"] || Hash.new

  # check if there is defined custom cache location in config
  $path_to_cache = File.join(config["cache_dir"].to_s, CACHE_FILE) unless config["cache_dir"].nil?

  # load content of cache file if it exists
  if(File.exist?($path_to_cache)) then
    $cache = File.open($path_to_cache, "r"){|from_file| Marshal.load(from_file)}
  else
    $cache = Hash.new
  end

  # check if cache is disable in config
  $disable_disk_cache = site.config["disable_disk_cache"] unless site.config["disable_disk_cache"].nil?

  # load macros
  unless config["macros"].nil? then
    for macro_definition in config["macros"]
      $global_macros[macro_definition[0]] = macro_definition[1]
    end
  end

  # make list of updated macros
  $updated_global_macros = get_list_of_updated_global_macros($global_macros, $cache["cached_global_macros"])

  # print macro information
  if $global_macros.size == 0 then
    puts "             LaTeX: no macros loaded"
  else
    puts "             LaTeX: " + $global_macros.size.to_s + " macro" +
      ($global_macros.size == 1 ? "" : "s") + " loaded" +
      ($updated_global_macros.size > 0 ? " (" + $updated_global_macros.size.to_s + " updated)" : "")
  end

  # load list of ignored files
  $ignored = config["ignore"] unless config["ignore"].nil?
end

Jekyll::Hooks.register :site, :after_reset do
  # reset count after reset
  $count_newly_generated_expressions = 0
end

Jekyll::Hooks.register :site, :post_write do
  # print new line to prevent overwriting previous output
  print "\n"
  # check if caching is enabled
  if !$disable_disk_cache then
    # save global macros to cache
    $cache["cached_global_macros"] = $global_macros
    # save cache to disk
    Dir.mkdir(File.dirname($path_to_cache)) unless File.exists?(File.dirname($path_to_cache))
    File.open($path_to_cache, "w"){|to_file| Marshal.dump($cache, to_file)}
  end
end

