require 'digest/sha1'

#
# Wraps the concept of an object in Git. Any versioned data in Git is
# considered an object. Current object types are:
#
# - blob
# - tree
# - commit
# - tag
#
# Any subclass +Klass+ of Git::Object is expected to conform to the following
# API:
#
# [<tt>Klass#initialize(*args)</tt>]
#   Must be able to accept no arguments and instantiate a completely empty
#   object. Otherwise, take the args passed (number, type, and purpose are
#   left to the subclass to define) and instantiate (but not save) an object
#   of that type.
#
# [<tt>Klass#to_s</tt>]
#   Must represent the contents in a string-like fashion. Must be directly
#   compatible wih the output of git-show for that type of object.
#
# [<tt>Klass#dump (private)</tt>]
#   Must return a string containing the raw dumped contents of the object,
#   compatible with git's standard format for that object.
#   
# [<tt>Klass#load(dump) (private)</tt>]
#   Must accept any string returned by _#dump_, and set the state of the
#   object to whatever it's state was at the time of the dump.
#
class Git::Object
  CANONICAL_FORMAT = "%s %d\0%s"
  
  def self.klass(type)
    const_get(type.to_s.capitalize)
  end
  
  def self.create(*args)
    new(*args).save
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
    self.class.name.downcase.sub!(/^.*::/, '').to_sym
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
  # object loaded through Git::Object::Blob must be a blob, even though the
  # method in the subclass is technically capable of loading any type of
  # object.
  #
  def self.verify_object_type(object)
    unless object.kind_of?(self)
      raise Git::ObjectTypeError,
        "expected #{object.hash} to be #{self.name} but was #{object.class.name}"
    end
  end
end

require 'git/object/blob'