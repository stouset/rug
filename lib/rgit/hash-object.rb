require 'rgit'

class Rgit::HashObject < Rgit
  def main(*files)
    if settings.stdin
      puts Git::Object.hash(settings.type, STDIN.read)
    else
      files.each do |name|
        puts Git::Object.hash(settings.type, File.read(name))
      end
    end
  end
  
  private
  
  def parser
    OptionParser.new do |opts|
      opts.banner = "Usage: rgit-hash-object [options] FILES..."
      opts.on('-t', '--type TYPE', [:blob, :tree, :commit], 'a git object type') {|settings.type|}
      opts.on('-s', '--stdin') {|settings.stdin|}
    end
  end
  
  def defaults
    OpenStruct.new(
      :type  => 'blob',
      :stdin => false
    )
  end
end