require 'enumerator'

class Git::Object::Tree < Git::Object
  INPUT_FORMAT = /^(\d+) (.+?)\0(.{20})/m
  
  MODE_MASK = 0770000
  MODES     = {
    0100000 => :file,
    0040000 => :tree,
  }
  
  attr_accessor :trees
  attr_accessor :files
  
  def self.load(data)
    each_entry(data) do |mode, name, hash|
      type = MODES[mode & MODE_MASK]
      
      
    end
    
    self.new()
  end
  
  def initialize()
  end
  
  def dump
  end
  
  private
  
  def self.each_entry(data, &blk)
    fields = data.split(INPUT_FORMAT)
    size   = (fields.length - 1) - fields.rindex('')
    
    fields.reject! {|f| f.empty? }
    
    fields.each_slice(size, &blk)
  end
end