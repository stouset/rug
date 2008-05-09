require 'enumerator'
require 'set'

class Git::Object::Tree < Git::Object
  INPUT_FORMAT = /^(\d+) (.+?)\0(.{20})/m
  
  MODE_MASK = 0777
  MODES     = {
    :tree   => 0040000,
    :file   => 0100000,
    :link   => 0120000,
    :commit => 0160000,
  }
  
  attr_accessor :entries
  attr_accessor :metadata
  
  def self.load(data)
    tree = self.new()
    
    each_entry(data) do |mode, name, hash|
      type = MODES.invert[mode & ~MODE_MASK]
      mode = mode & MODE_MASK
        
      self.entries << Git::Object.find(hash)
      self.metadata[hash] = { :name => name, :mode => mode }
    end
    
    tree
  end
  
  def initialize()
    self.entries  = Set.new
    self.metadata = {}
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