require 'git'

require 'optparse'
require 'ostruct'
require 'singleton'

OpenStruct.class_eval { undef :id, :type }

class Rgit
  include Singleton
  
  def self.run!(args = ARGV)
    self.instance.run!(args.dup)
  end
  
  def run!(args)
    parser.parse!(args)
    main(*args)
  rescue OptionParser::ParseError
    puts parser
  rescue Git::StandardError => e
    puts "#{e.message} (#{e.backtrace.first})"
  end
  
  def settings
    @settings ||= defaults
  end
  
  def defaults
    OpenStruct.new
  end
end