require 'execjs'
require 'digest'
require 'htmlentities'


PATH_TO_JS = File.join(__dir__, "/katex.min.js")
DEFAULT_CACHE_DIR = ".jekyll-cache"
CACHE_FILE = "jektex-cache.marshal"
KATEX = ExecJS.compile(open(PATH_TO_JS).read)
PARSE_ERROR_PLACEHOLDER = "<b style='color: red;'>PARSE ERROR</b>"
$global_macros = Hash.new
$count_newly_generated_expressions = 0
$path_to_cache = File.join(DEFAULT_CACHE_DIR, CACHE_FILE)
$cache = nil
$disable_disk_cache = false

def convert(page)
  # convert HTML entities back to characters
  post = HTMLEntities.new.decode(page.output.to_s)
  post = post.gsub(/(\\\()((.|\n)*?)(?<!\\)\\\)/) { |m| escape_method($1, $2, page.path) }
  post = post.gsub(/(\\\[)((.|\n)*?)(?<!\\)\\\]/) { |m| escape_method($1, $2, page.path) }
  return post
end

def escape_method( type, string, doc_path )
  @display = false

  # detect if expression is display view
  case type.downcase
    when /\(/
      @display = false
    else /\[/
      @display = true
  end

  # generate a hash from the math expression
  @expression_hash = Digest::SHA2.hexdigest(string) + @display.to_s

  # use it if it exists
  if($cache.has_key?(@expression_hash))
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
      # this stops jekyll being immune to interupts and kill command
      raise
    rescue Exception => e
      # catch parse error
      puts "\e[31m " + e.message.gsub("ParseError: ", "") + "\n\t"  + doc_path + "\e[0m"
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

def print_stats
  print "             LaTeX: " + 
        ($count_newly_generated_expressions).to_s +
        " expressions rendered (" + $cache.size.to_s +
        " already cached)        \r"
  $stdout.flush
end

Jekyll::Hooks.register :pages, :post_render do |page|
  page.output = convert(page)
end

Jekyll::Hooks.register :documents, :post_render do |doc|
  doc.output = convert(doc)
end

Jekyll::Hooks.register :site, :after_init do |site|
  # load macros from config file
  if site.config["jektex-macros"] != nil
    for macro_definition in site.config["jektex-macros"]
      $global_macros[macro_definition[0]] = macro_definition[1]
    end
  end
  # print macro information
  if $global_macros.size == 0
    puts "             LaTeX: no macros loaded"
  else
    puts "             LaTeX: " + $global_macros.size.to_s + " macro" +
          ($global_macros.size == 1 ? "" : "s") + " loaded"
  end

  # check if cache is disable in config
  if site.config["disable_disk_cache"] != nil
    $disable_disk_cache = site.config["disable_disk_cache"]
  end

  # check if there is defined custom cache location in config
  if site.config["jektex_cache_dir"] != nil
    $path_to_cache = File.join(site.config["jektex_cache_dir"].to_s, CACHE_FILE)
  end

  # load content of cache file if it exists
  if(File.exist?($path_to_cache))
    $cache = File.open($path_to_cache, "r"){|from_file| Marshal.load(from_file)}
  else
    $cache = Hash.new
  end
end

Jekyll::Hooks.register :site, :after_reset do
  # reset count after reset
  $count_newly_generated_expressions = 0
end

Jekyll::Hooks.register :site, :post_write do
  # print new line to prevent overwriting previous output
  print "\n"
  # check if caching is enabled
  if $disable_disk_cache == false
    # save cache to disk
    Dir.mkdir(File.dirname($path_to_cache)) unless File.exists?(File.dirname($path_to_cache))
    File.open($path_to_cache, "w"){|to_file| Marshal.dump($cache, to_file)}
  end
end
