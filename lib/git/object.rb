require 'digest/sha1'

class Git::Object
  CANONICAL_FORMAT = "%s %d\0%s"
  
  def self.find(hash)
    store  = Git::Store.find(hash)
    object = store && store.object
    
    if object
      verify_object_type(object)
      object
    end
  end
  
  def self.load(type, dump)
    klass = const_get(type.capitalize)
    klass.load(dump)
  end
  
  def save
    file = Git::Store.create(self)
    file.hash
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
  
  def hash
    Digest::SHA1.hexdigest(canonical)
  end
  
  private
  
  def self.verify_object_type(object)
    unless object.kind_of?(self)
      raise Git::ObjectTypeError,
        "expected #{object.hash} to be #{self.name} but was #{object.class.name}"
    end
  end
end

require 'git/object/blob'