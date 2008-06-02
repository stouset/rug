require 'rgit'

class Rgit::CatFile < Rgit
  def main(*ids)
    # we do this to match git's behavior
    raise OptionParser::ParseError unless ids.length           == 1
    raise OptionParser::ParseError unless settings.mode.length == 1
    
    id   = ids.shift
    mode = settings.mode.shift
    
    # need to exit 1 if the object couldn't be found
    object = Git::Object.find(id) rescue exit(1)
    
    puts case mode
      when :type   then object.type
      when :size   then object.dump.length
      when :exists then exit(0) # do this explicitly
      when :print  then object
    end
  end
  
  protected
  
  def parser
    #
    # TODO: support <type> like git-cat-file
    #
    OptionParser.new do |opts|
      opts.banner = "Usage: rgit-cat-file [-t|-s|-e|-p] <id>"
      
      opts.on('-t', '--type',
        "print the object's type") \
        { settings.mode << :type }
      
      opts.on('-s', '--size',
        "print the object's size") \
        { settings.mode << :size }
      
      opts.on('-e', '--exists',
        'exit with zero status if the object exists' ) \
        { settings.mode << :exists }
      
      opts.on('-p', '--print',
        'pretty-print the object contents') \
        { settings.mode << :print }
    end
  end
  
  def defaults
    OpenStruct.new(
      :mode  => []  # capture all listed modes to complain on multiples
    )
  end
end
