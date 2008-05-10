require 'git/lazy_object'

require 'digest/sha1'

class Git::Object
  class << self
    include Git::LazyObject
  end
  
  CANONICAL_FORMAT = "%s %d\0%s"
  
  def self.find(hash)
    store  = Git::Store.find(hash)
    object = store && store.object
    
    verify_object_type(object) if object
    
    object
  end
  
  def self.load(type, dump)
    klass = get_klass(type)
    klass.new.load(dump)
  end

  def save
    Git::Store.create(self)
  end
  
  def type
    self.class.name.downcase.sub!(/^.*::/, '')
  end
  
  def canonical
    CANONICAL_FORMAT % [ type, dump.length, dump ]
  end
  
  def dump
    _dump
  end
  
  def load(dump)
    _load(dump)
    self
  end
  
  def hash
    Digest::SHA1.hexdigest(canonical)
  end
  
  private
  
  def self.get_klass(type)
    const_get(type.to_s.capitalize)
  end
  
  #
  # Checks that the object is of the same class this method is being run in.
  # Raises an exception if this is not the case. This allows us to check that
  # an object loaded through Git::Object is any kind of Git::Object, but an
  # object loaded through Git::Object::Blob must be a blob.
  #
  def self.verify_object_type(object)
    unless object.kind_of?(self)
      raise Git::ObjectTypeError,
        "expected #{object.hash} to be #{self.name} but was #{object.class.name}"
    end
  end
end

require 'git/object/blob'