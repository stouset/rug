require 'pathname'

class Git::Object::Tree < Git::Object
  INPUT_FORMAT = /(\d+) (.+?)\0(.{20})/m
  
  MODE_MASK = 0777
  
  MODE_FOR  = {
    :tree   => 0040000,
    :blob   => 0100000,
    :link   => 0120000,
# submodules aren't supported yet
#    :commit => 0160000,
  }
  
  TYPE_FOR = MODE_FOR.invert
  
  attr_accessor :entries
  
  def initialize(*paths)
    self.entries = []
    
    paths.each {|name| self << path }
  end
  
  def <<(path)
    unless path.kind_of?(Pathname)
      path = Pathname.new(path)
    end
    
    unless path.subdir_of?(Git::WORK_DIR)
      raise Git::InvalidTreeEntry, "#{path} is outside of repository"
    end
    
    path = path.relative_path_from(Git::WORK_DIR)
    
    case self.class.type(path.lstat)
      when :blob then add_file(path)
      when :tree then add_dir(path)
      when :link then add_link(path)
      else raise Git::InvalidTreeEntry, "#{path} is of unknown type"
    end
  end
  
  def _dump
  end
  
  def _load(dump)
  end
  
  private
  
  def self.type(mode)
    TYPE_FOR[mode & ~MODE_MASK]
  end
  
  def self.mode(mode)
    case self.type(mode)
      when :blob then mode & MODE_MASK
      else            0000
    end
  end
  
  private
  
  def add_file(path)
  end

  # def each_entry(dump)
  #   fields = dump.split(INPUT_FORMAT)
  #   fields.reject! {|f| f.empty? }
  #   
  #   fields.enum_slice(3).each do |mode, name, hash|
  #     mode = mode.to_i(8)             # mode is in octal
  #     hash = hash.unpack('H40').first # hash is in binary format
  #     yield(mode, name, hash)
  #   end
  # end
end

class Git::Object::Tree::Entry
  attr_reader :name
  attr_reader :mode
  attr_reader :object
  
  def self.proxy(name, mode, type, hash)
    proxy = self.new(name, mode, 'deferred')
    proxy.send(:proxy_object!, type, hash)
    proxy
  end
  
  def initialize(name, mode, object)
    self.name   = name
    self.mode   = mode
    self.object = object
  end
  
  def type
    object.type
  end
  
  private
  
  attr_writer :name
  attr_writer :mode
  attr_writer :object
  
  def proxy_object!(type, hash)
    metaclass = class << self; self; end
    metaclass.send(:alias_method, :proxy_object,  :object)
    metaclass.send(:alias_method, :proxy_type,    :type)

    metaclass.send(:define_method, :object) do
      unproxy_object!
      self.object = Git::Object.klass(type).find(hash)
    end
    
    metaclass.send(:define_method, :type) { type }
  end
  
  def unproxy_object!
    class << self
      alias_method :object, :proxy_object
      alias_method :type,   :proxy_type
    end
  end
end