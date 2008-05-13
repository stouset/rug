require 'enumerator'

class Git::Object::Tree < Git::Object
  INPUT_FORMAT = /(\d+) (.+?)\0(.{20})/m
  
  MODE_MASK = 0777
  MODES     = {
    :tree   => 0040000,
    :blob   => 0100000,
    :link   => 0120000,
    :commit => 0160000,
  }
  
  attr_accessor :entries
  attr_accessor :metadata
  
  def initialize()
    self.entries  = []
    self.metadata = {}
  end
  
  def entries
    @entries.map! do |e|
      case e
        when String then Git::Object.klass(metadata[e][:type]).find(e)
        else             e
      end
    end
  end
  
  private
  
  def _dump
    'blah'
  end
  
  def _load(dump)
    each_entry(dump) do |mode, name, hash|
      type = MODES.invert[mode & ~MODE_MASK]
      mode = mode & MODE_MASK
      
      @entries << hash
      self.metadata[hash] = { :name => name, :type => type, :mode => mode }
    end
  end
  
  private
  
  def each_entry(dump)
    fields = dump.split(INPUT_FORMAT)
    fields.reject! {|f| f.empty? }
    
    fields.enum_slice(3).each do |mode, name, hash|
      mode = mode.to_i(8)             # mode is in octal
      hash = hash.unpack('H40').first # hash is in binary format
      yield(mode, name, hash)
    end
  end
end