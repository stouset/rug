require 'git/proxyable'

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
# [<tt>Klass#children</tt> (optional)]
#   If the subclass points to other git objects (as in the case of trees or
#   commits), it must define this method to return the list of all such
#   objects for the purpose of saving them. Must only return one level of
#   depth. Objects which are proxied (and therefore unchanged) should be
#   excluded from this list.
#
# [<tt>Klass#inspect</tt> (optional)]
#   If the subclass points to other git objects, the inspect method should not
#   display children, to sanely deal with deeply-nested objects at the
#   console.
# 
# [<tt>Klass#to_s</tt>]
#   Must represent the contents in a string-like fashion. Must be directly
#   compatible wih the output of 'git-cat-file -p' for that type of object.
# 
# [<tt>Klass#_dump</tt> (private)]
#   Must return a string containing the raw dumped contents of the object,
#   compatible with git's standard format for that object.
# 
# [<tt>Klass#_load(dump)</tt> (private)]
#   Must accept any string returned by +_dump+, and set the state of itself
#   to its state at the time of the dump. May assume it was initialized with
#   no arguments, and has not since been modified.
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
      object = load(store.type, store.dump)
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
  
  def eql?(other)
    # due to our use of SHA-1, this _should_ fail in a reasonable and expected
    # manner when the other object isn't a Git object
    self.hash == other.hash
  end
  
  alias == eql?
  
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
require 'git/object/commit'
require 'git/object/tree'
