require 'execjs'
require 'digest'
require 'htmlentities'


PATH_TO_JS = __dir__ + "/katex.min.js"
CACHE_DIR = "./.jektex-cache/"
CACHE_FILE = "jektex-cache.marshal"
PATH_TO_CACHE = CACHE_DIR + CACHE_FILE
KATEX = ExecJS.compile(open(PATH_TO_JS).read)
PARSE_ERROR_PLACEHOLDER = "<b style='color: red;'>PARSE ERROR</b>"
$global_macros = Hash.new
$count_newly_generated_expressions = 0
$cache = nil
$disable_disk_cache = false

def convert(doc)
  # convert HTML enetities back to characters
  post = HTMLEntities.new.decode(doc.to_s)
  post = post.gsub(/(\\\()((.|\n)*?)(?<!\\)\\\)/) { |m| escape_method($1, $2, doc.path) }
  post = post.gsub(/(\\\[)((.|\n)*?)(?<!\\)\\\]/) { |m| escape_method($1, $2, doc.path) }
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
      File.open(PATH_TO_CACHE, "w"){|to_file| Marshal.dump($cache, to_file)}
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

Jekyll::Hooks.register :documents, :post_render do |doc|
  doc.output = convert(doc)
end

Jekyll::Hooks.register :site, :after_init do |site|
  # load macros from config file
  if site.config["latex-macros"] != nil
    for macro_definition in site.config["latex-macros"]
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

  if site.config["disable_disk_cache"] != nil
    $disable_disk_cache = site.config["disable_disk_cache"]
  end

  # load content of cache file if it exists
  if(File.exist?(PATH_TO_CACHE))
    $cache = File.open(PATH_TO_CACHE, "r"){|from_file| Marshal.load(from_file)}
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
  puts 
  # check if caching is enabled
  if $disable_disk_cache == false
    # save cache to disk
    Dir.mkdir(CACHE_DIR) unless File.exists?(CACHE_DIR)
    File.open(PATH_TO_CACHE, "w"){|to_file| Marshal.dump($cache, to_file)}
  end
end
