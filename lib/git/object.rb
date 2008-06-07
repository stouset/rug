require 'git/proxyable'
require 'digest/sha1'

class Git::Object
  CANONICAL_FORMAT = "%s %d\0%s"
  
  attr_accessor :store
  
  def self.type
    # TODO: optimize this regexp
    name.downcase.sub!(/^.*::/, '').to_sym
  end
  
  def self.create(store, *args)
    new(store, *args).save
  end
  
  def self.find(store, id)
    type, dump = store.get(id)
    object     = load(store, type, dump)
    verify_object_type(object)
    object
  end
  
  def self.each(store)
    raise NotImplementedError, "can't iterate over all #{type}s"
  end
  
  def self.canonical(type, dump)
    CANONICAL_FORMAT % [ type, dump.length, dump ]
  end
  
  def self.id(type, dump)
    Digest::SHA1.hexdigest(canonical(type, dump))
  end
  
  def initialize(store)
    self.store = store
  end
  
  def ==(other)
    # due to our use of SHA-1, this _should_ fail in a reasonable and expected
    # manner when the other object isn't a Git object
    self.id == other.id
  end
  
  alias eql? ==
  
  def id
    self.class.id(type, dump)
  end
  
  alias hash id
  
  def save
    store.put(id, type, dump)
  end
  
  def type
    self.class.type
  end
  
  def canonical
    self.class.canonical(type, dump)
  end
  
  def load(dump)
    _load(dump)
    self
  end
  
  def dump
    _dump
  end
  
  def inspect
    "#<#{self.class.name} #{id}>"
  end
  
  def to_tree
    raise Git::ObjectTypeError,
      "#{type} isn't tree-ish"
  end
  
  private
  
  private_class_method :new
  
  def self.inherited(subclass)
    subclass.public_class_method :new
  end
  
  def self.klass(type)
    const_get(type.to_s.capitalize)
  end
  
  def self.load(store, type, dump)
    klass(type).new(store).load(dump)
  end
  
  #
  # Checks that the object is of the same class this method is being run in.
  # Raises an exception if this is not the case. This allows us to check that
  # an object loaded through Git::Object is any kind of Git::Object, but an
  # object loaded through Git::Object::Blob must be a blob, even though the
  # method in the subclass is technically capable of loading any type of
  # object.
  #
  def self.verify_object_type(object)
    unless object.kind_of?(self)
      raise Git::ObjectTypeError,
        "expected a #{self.type} but was a #{object.type}"
    end
  end
end

require 'git/object/blob'
# require 'git/object/commit'
# require 'git/object/tree'
