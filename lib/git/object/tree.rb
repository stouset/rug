require 'enumerator'

class Git::Object::Tree < Git::Object
  include Git::Proxyable
  include Enumerable
  
  INPUT_FORMAT  = /(\d+) ([^\0]+)\0(.{20})/m
  OUTPUT_FORMAT = "%o %s\0%s"
  PRETTY_FORMAT = "%06o %s %s\t%s"
  
  PERMISSION_MASK = 0777
  
  MODE_FOR  = {
    :tree   => 0040000,
    :blob   => 0100000,
    :link   => 0120000,
# submodules aren't supported yet
#    :commit => 0160000,
  }
  
  TYPE_FOR = MODE_FOR.invert
  
  attr_proxied :entries
  
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
  
  def each(&block)
    entries.each(&block)
  end
  
  def descend(path = '.', &block)
    path = path.to_path
    
    entries.each do |entry|
      p = path.join(entry.name)
      yield(entry, p)
      entry.object.descend(p, &block) if entry.type == :tree
    end
  end
  
  def delete(path)
    path = path.to_path
    path = path.relative_path_from(Git::Repository.work_path) if path.absolute?
    
    dirname, basename = path.split
    
    # TODO: finish
  end
  
  def children
    @entries.map {|e| e.object }
  end
  
  def to_s
    entries.map do |entry|
      mode = entry.mode
      type = entry.type
      hash = entry.object.hash
      name = entry.name
      
      PRETTY_FORMAT % [ mode, type, hash, name ]
    end.join("\n") << "\n"
  end
  
  def inspect
    %{ #<#{self.class.name}:#{self.object_id.to_s(16)}
         @entries="..."> }.strip.gsub(%r{\s+}, ' ')
  end
  
  def to_tree
    self
  end
  
  private
  
  def _dump
    entries.map do |entry|
      name = entry.name
      mode = entry.mode
      hash = [entry.object.hash].pack('H40')
      OUTPUT_FORMAT % [mode, name, hash]
    end.join('')
  end
  
  def _load(dump)
    proxy!(dump) do
      fields = dump.split(INPUT_FORMAT)
      fields.each_slice(4) do |dummy, mode, name, hash|
        mode  = mode.to_i(8)
        type  = self.class.type(mode)
        perms = self.class.permissions(mode)
        hash  = hash.unpack('H40').first
        
        object   = Git::Object.find(hash)
        entries << Git::Object::Tree::Entry.new(name, type, perms, object)
      end
    end
  end
  
  #
  # Determines the type of object a file will need based on its entire +mode+.
  # Uses TYPE_FOR as a lookup table.
  #
  def self.type(mode)
    TYPE_FOR[mode & ~PERMISSION_MASK]
  end
  
  #
  # Extracts the permissions part of +mode+. Only blobs have permission bits
  # set, so returns 0 for all other object types.
  #
  def self.permissions(mode)
    case self.type(mode)
      when :blob then mode & PERMISSION_MASK
      else            0000
    end
  end
  
  #
  # Performs a binary search on the immediate children of the tree for an
  # entry with the +name+ passed.
  #
  # Returns the index of the +entry+, in the +tree+, if found. If not found,
  # returns a negative value that encodes the index the entry should be
  # inserted in to maintain sorted order. The negative number can be converted
  # into the correct insertion index by using the invert_index function.
  #
  # Uses the git tree sort order as defined in Git::Object::Tree::Entry#<=>.
  #
  def self.search(tree, entry)
    entries = tree.entries
    
    low  = 0
    high = entries.length # not length - 1, because it could sort after
    
    while low < high
      mid = (low + high) / 2
      
      case entry <=> entries[mid]
        when -1 then high = mid     # re-cap high end
        when  0 then return mid     # found entry
        when  1 then low = mid + 1  # re-cap low end
        else raise 'Entry<=> returned something insane'
      end
    end
    
    # not found, return the encoded index
    invert_index(low)
  end
  
  #
  # Inserts an +entry+ into the +tree+ at the given +index+. Uses an index
  # returned from search. If the entry already exists, simply returns the
  # existing one.
  #
  def self.insert(tree, index, entry)
    if index >= 0
      tree.entries[index]
    else
      tree.entries.insert(invert_index(index), entry)
      entry
    end
  end
  
  #
  # Adds a file at +path+ to the tree. Expects a relative path.
  #
  # Returns the blob added.
  #
  def add_file(path)
    add_entry(path) { Git::Object::Blob.new(path.read) }
  end
  
  #
  # Adds a directory (and none of its contents) at +path+ to the tree. Is a
  # noop if the path is '.'. Expects a relative path.
  #
  # There's an implicit recursion here between add_dir and add_entry. The
  # add_dir method attempts to add the entire directory. In add_entry, the
  # path is split, and the remaining directory component is added via add_dir.
  #
  # Returns the tree added.
  #
  def add_dir(path)
    return self if path.dot?
    add_entry(path) { Git::Object::Tree.new }
  end
  
  #
  # Adds +path+ and all children to the tree. Expects a relative path.
  #
  # Returns the tree added.
  #
  def add_path(path)
    path.children.each {|entry| self << path.join(entry) }
  end
  
  #
  # Adds the symlink at +path+ to the tree. Expects a relative path.
  #
  # Returns the link added.
  #
  def add_link(path)
    add_entry(path) { Git::Object::Blob.new(path.readlink) }
  end
  
  #
  # Performs the actual addition of an entry to the tree. Inserts the object
  # returned from the block to the location at +path+. If an entry already
  # exists at +path+, is a no-op.
  #
  # Creates parent trees as needed. Returns the _object_ added, not its entry.
  #
  def add_entry(path)
    dirname, basename = path.split
    
    # it really sucks that we have to instantiate an entire entry, plus call
    # the block, plus do an lstat, _just_ to get sort comparison in search
    # TODO: really need to rethink how to make this faster
    entry = begin
      name   = basename.to_s
      mode   = path.lstat.mode
      type   = self.class.type(mode)
      perms  = self.class.permissions(mode)
      object = yield
      
      Git::Object::Tree::Entry.new(name, type, perms, object)
    end
    
    # find the parent tree
    tree = add_dir(dirname)
    
    # search for the entry in the tree, and insert it
    index = self.class.search(tree, entry)
    self.class.insert(tree, index, entry).object
  end
  
  #
  # Encodes and decodes an index for use when an entry isn't found in the
  # tree, but we still want the index for insertion purposes and need to
  # distinguish between the two cases.
  #
  def self.invert_index(index)
    -(index + 1)
  end
end

class Git::Object::Tree::Entry
  include Comparable
  
  TREE_SUFFIX = '/'
  
  attr_reader :name
  attr_reader :type
  attr_reader :perms
  attr_reader :object
  
  def initialize(name, type, perms, object)
    self.name   = name
    self.type   = type
    self.perms  = perms
    self.object = object
    
    # prime this before freeze
    self.sort_key
    
    freeze
  end
  
  def <=>(other)
    return nil unless other.kind_of?(self.class)
    return 0   if self.name == other.name
    
    self.sort_key <=> other.sort_key
  end
  
  def mode
    Git::Object::Tree::MODE_FOR[type] | perms
  end
  
  protected
  
  attr_writer :type
  attr_writer :perms
  attr_writer :object
  
  def name=(value)
    # strip off trailing slashes for conformity
    value = value.chop if value[-1, 1] == '/'
    @name = value
  end
  
  def sort_key
    @sort_key ||= name + (type == :tree ? TREE_SUFFIX : '')
  end
end