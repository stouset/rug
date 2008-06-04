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
  rescue ArgumentError => e
    # only catch ArgumentError from calling main with bad args
    case e.backtrace.first
      when %r{`main'$} then puts parser
      else                  raise e
    end
  rescue Git::StandardError => e
    puts "fatal: #{e.message} (#{e.backtrace.first})"
  end
  
  def settings
    @settings ||= defaults
  end
  
  def defaults
    OpenStruct.new
  end
end