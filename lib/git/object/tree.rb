#
#
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
  
  #
  # Creates a new instance of a Tree. Calls +#<<+ on all paths passed.
  #
  def initialize(*paths)
    self.entries = []

    paths.each {|path| self << path }
  end
  
  #
  # Appends a +path+ to the tree. If +path+ is a file or a symlink, adds the
  # file to the tree and any directories needed to reach that file. If +path+
  # is a directory, adds all children of that directory to thes tree,
  # recursively.
  #
  # Accesses the filesystem to determine the type of object at the path, its
  # permissions, and any parts of the filesystem leading up to id.
  #
  def <<(path)
    # convert to a relative path, just in case
    path = path.to_path
    path = path.relative_path_from(Git::Repository.work_path) if path.absolute?
    
    # don't add any subdir of the repository path
    return if path.subdir_of?(Git::Repository.git_path)

    # raise an exception if the path isn't under the working tree
    unless path.subdir_of?(Git::Repository.work_path)
      raise Git::InvalidTreeEntry, "#{path} is outside of repository"
    end
    
    # call the specific add_* for the type of entry
    case self.class.type(path.lstat.mode)
      when :blob then add_file(path)
      when :tree then add_path(path)
      when :link then add_link(path)
      else raise Git::InvalidTreeEntry, "#{path} is of unsupported type"
    end
  end
  
  private
  
  def _dump
  end
  
  def _load(dump)
  end
  
  #
  # Determines the type of object a file will need based on its entire +mode+.
  # Uses TYPE_FOR as a lookup table.
  #
  def self.type(mode)
    TYPE_FOR[mode & ~MODE_MASK]
  end
  
  #
  # Extracts the permissions part of +mode+. Only blobs have permission bits
  # set, so returns 0 for all other object types.
  #
  def self.mode(mode)
    case self.type(mode)
      when :blob then mode & MODE_MASK
      else            0000
    end
  end
  
  #
  # Performs a binary search on the immediate children of the tree for an
  # entry with the +name+ passed.
  #
  # Returns the index of the entry, if found. If not found, returns a negative
  # value that encodes the index the entry should be inserted in, to maintain
  # sorted order. The negative number can be converted into the correct
  # insertion index by using the invert_index function.
  #
  # Uses git's sorting rules to preserve order. T
  #
  #
  #
  #
  #
  #
  def self.search(tree, entry)
    entries = tree.entries
    
    low  = 0
    high = entries.length # not length - 1, because it could sort after
    
    while low < high
      mid = (low + high) / 2
      
      case entry <=> entries[mid]
        when -1 then high = mid - 1
        when  0 then return mid
        when  1 then low = mid + 1
        else raise 'Entry<=> returned something insane'
      end
    end

    # return the encoded index; low, mid, and high should be equal
    invert_index(low)
  end
  
  def self.insert(tree, index, entry)
    case index > 0
      when true then tree.entries[index] = entry
      else           tree.entries.insert(invert_index(index), entry)
    end

    entry
  end
  
  def add_file(path)
    add_entry(path) { Git::Object::Blob.new(path.read) }
  end
  
  def add_dir(path)
    return self if path.dot?
    add_entry(path) { Git::Object::Tree.new }
  end
  
  def add_path(path)
    path.children.each {|entry| self << path.join(entry) }
  end
  
  def add_link(path)
    add_entry(path) { Git::Object::Blob.new(path.readlink) }
  end
  
  #
  # Performs the actual addition of an entry to the tree. Inserts the object
  # returned from +yield+ to the location at +path+. If the object is already
  # in the tree, overwrites it.
  #
  # Creates parent trees as needed.
  #
  def add_entry(path)
    dirname, basename = path.split
    
    # create the entry, scope in begin/end just for nice grouping
    entry = begin
      name   = basename.to_s
      mode   = self.class.mode(path.lstat.mode)
      object = yield
      
      Git::Object::Tree::Entry.new(name, mode, object)
    end

    tree  = add_dir(dirname)
    index = self.class.search(tree, entry)

    self.class.insert(tree, index, entry).object
  end

  def self.invert_index(index)
    -(index + 1)
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
  include Comparable

  TREE_SUFFIX = '/'

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
  
  #
  # The comparison function for tree entries. Only compares the binary
  # resperentation of entry names.
  #
  # Uses the git tree comparison function. Compares names in ASCIIbetic order,
  # but implicitly appends TREE_SUFFIX to directories if not already there.
  #
  def <=>(other)
    self.class.sort_key(self) <=> self.class.sort_key(other)
  end

  def type
    object.type
  end
  
  def inspect
    %{ #<#{self.class.name}:#{self.object_id.to_s(16)}
         @name="#{name}"
         @mode="#{mode.to_s(8)}"
         @object="..."> }.strip.gsub(%r{\s+}, ' ')
  end

  private
  
  attr_writer :name
  attr_writer :mode
  attr_writer :object
  
  #
  # Retrieves the sort key for an entry. The sort key is the binary
  # representation of the name, with TREE_SUFFIX appended if the entry is a
  # tree.
  #
  def self.sort_key(entry)
    name = entry.name
    name + TREE_SUFFIX if entry.type == :tree && name[-1, 1] != TREE_SUFFIX
    name.unpack('C*')
  end

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