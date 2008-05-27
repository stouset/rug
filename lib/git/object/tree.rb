class Git::Object::Tree < Git::Object
  INPUT_FORMAT = /(\d+) (.+?)\0(.{20})/m
  TREE_POSTFIX = '/'
  
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
    
    paths.each {|path| self << path }
  end
  
  def <<(path)
    path = path.to_path
    
    unless path.subdir_of?(Git::Repository.work_path)
      raise Git::InvalidTreeEntry, "#{path} is outside of repository"
    end
    
    case self.class.type(path.lstat.mode)
      when :blob then add_file(path)
      when :tree then add_path(path)
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
  
  def self.search(entries, name, is_dir)
    name   = name.to_s
    name   = name + TREE_POSTFIX if is_dir
    
    low  = 0
    high = entries.length
    
    while low < high
      mid    = (low + high) / 2
      ename  = entries[mid].name
      ename += TREE_POSTFIX if entries[mid].type == 'tree'
      
      case name <=> ename
        when -1 then high = mid
        when  0 then return mid
        when  1 then low = mid + 1
        else raise 'String#<=> returned something insane'
      end
    end
      
    -(low + 1)
  end
  
  def self.insert(entries, index, entry)
    entries.insert(-1 - index, entry)
  end
  
  def add_file(path)
    add_entry(path) { Git::Object::Blob.new(path.read) }
  end
  
  def add_dir(path)
    return self if path.dot?
    add_entry(path) { Git::Object::Tree.new }
  end
  
  def add_path(path)
    path.children.each do |entry|
      # skip over paths under the repository
      next if entry.subdir_of?(Git::Repository.git_path)
      self << path.join(entry)
    end
  end
  
  def add_link(path)
    add_entry(path) { Git::Object::Blob.new(path.readlink) }
  end
  
  def add_entry(path)
    return if path.subdir_of?(Git::Repository.git_path)
    
    dirname, basename = path.split
    
    is_dir = path.directory? and not path.symlink?
    tree   = add_dir(dirname)
    index  = self.class.search(tree.entries, basename, is_dir)
    
    if (index < 0)
      name   = basename.to_s
      mode   = self.class.mode(path.lstat.mode)
      object = yield
      entry  = Git::Object::Tree::Entry.new(name, mode, object)
      
      self.class.insert(tree.entries, index, entry)
      object
    else
      tree.entries[index].object
    end
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
    metaclass.send(:alias_method, :proxy_object, :object)
    metaclass.send(:alias_method, :proxy_type,   :type)
    
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