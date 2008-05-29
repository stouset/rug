require 'git'

require 'optparse'
require 'ostruct'
require 'singleton'

OpenStruct.class_eval { undef :id, :type }

class Rgit
  include Singleton
  
  def self.run!(args = ARGV)
    self.instance.run!(args)
  end
  
  def run!(args)
    rest = parser.parse(args)
    main(*rest)
  rescue OptionParser::ParseError
    puts parser
  end
  
  def settings
    @settings ||= defaults
  end
  
  def defaults
    OpenStruct.new
  end
end