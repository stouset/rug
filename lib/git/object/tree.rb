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
  
  def initialize(dir = nil)
    self.entries  = []
    self.metadata = {}
    
    if File.directory?(dir.to_s)
      Dir.foreach(dir) do |name|
        next if (%w{ . .. } << Git::GIT_DIR ).include?(name)
        
        name  = File.join(dir, name)
        stat  = File.stat(name)
        type  = self.class.type(stat.mode)
        mode  = self.class.mode(stat.mode)
        
        entry = case type
          when :blob then Git::Object::Blob.new(File.read(name))
          when :tree then Git::Object::Tree.new(name)
          when :link then Git::Object::Blob.new(File.readlink(name))
        end
        
        entry.hash rescue next
        
        metadata[entry.hash] = { :name => name, :type => type, :mode => mode }
        @entries << entry
      end
    end
  end
  
  def entries
    @entries.map! do |e|
      case e
        when String then Git::Object.klass(metadata[e][:type]).find(e)
        else             e
      end
    end
  end
  
  def _dump
    'dummy'
  end
  
  def _load(dump)
    each_entry(dump) do |mode, name, hash|
      type = self.class.type(mode)
      mode = self.class.mode(mode)
      
      @entries << hash
      self.metadata[hash] = { :name => name, :type => type, :mode => mode }
    end
  end
  
  private
  
  def self.type(mode)
    MODES.invert[mode & ~MODE_MASK]
  end
  
  def self.mode(mode)
    self.type(mode) == :blob ? mode & MODE_MASK : 0000
  end
  
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