require 'digest/sha1'

class Git::Object
  CANONICAL_FORMAT = "%s %d\0%s"
  
  def self.klass(type)
    const_get(type.to_s.capitalize)
  end
  
  def self.find(hash)
    if store = Git::Store.find(hash)
      object = store.object
      verify_object_type(object)
      object
    end
  end
  
  def self.exists?(hash)
    Git::Store.exists?(hash)
  end
  
  def self.load(type, dump)
    klass(type).new.load(dump)
  end
  
  def self.canonical(type, dump)
    CANONICAL_FORMAT % [ type, dump.length, dump ]
  end
  
  def self.hash(type, dump)
    Digest::SHA1.hexdigest(canonical(type, dump))
  end
  
  def save
    Git::Store.create(self.hash, self.type, self.dump).hash
  end
  
  def type
    self.class.name.downcase.sub!(/^.*::/, '')
  end
  
  def canonical
    self.class.canonical(type, dump)
  end
  
  def hash
    self.class.hash(type, dump)
  end
  
  def dump
    _dump
  end
  
  def load(dump)
    _load(dump)
    self
  end
  
  private
  
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