require 'rgit'

class Rgit::HashObject < Rgit
  def main(*files)
    # use stdin exclusively if set, otherwise use the named files
    streams = case settings.stdin
      when true then [STDIN]
      else           files.map {|f| Pathname.new(f) }
    end
    
    streams.each do |stream|
      type = settings.type.to_sym
      dump = stream.read
      hash = Git::Object.hash(settings.type, dump)
      
      puts hash
      
      if settings.write
        Git::Store.create(hash, type, dump)
      end
    end
  end
  
  private
  
  def parser
    OptionParser.new do |opts|
      opts.banner = "Usage: rgit-hash-object [options] FILES..."
      
      opts.on('-t', '--type TYPE',
        Git::Object.types,
        "the object type (default blob)") {|settings.type|}
        
      opts.on('-w', '--write') {|settings.write|}
      opts.on('-s', '--stdin') {|settings.stdin|}
    end
  end
  
  def defaults
    OpenStruct.new(
      :type  => 'blob',
      :write => false,
      :stdin => false
    )
  end
end