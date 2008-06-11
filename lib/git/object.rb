require 'git/proxyable'
require 'digest/sha1'

class Git::Object
  include Proxyable
  
  CANONICAL_FORMAT = "%s %d\0%s"
  
  OBJECT_CACHE = Hash.new {|h, k| h[k] = {} }
  
  def self.create(store, *args)
    new(store, *args).save
  end
  
  def self.find(store, id)
    cache[store][id] ||= begin
      type, dump = store.get(id)
      load(store, type, dump)
    end
    
    object = cache[store][id]
    object.kind_of?(self) ? object : object.send(:"to_#{type}")
  end
  
  def self.id(type, dump)
    Digest::SHA1.hexdigest(canonical(type, dump))
  end
  
  def self.canonical(type, dump)
    CANONICAL_FORMAT % [ type, dump.length, dump ]
  end
  
  def self.type
    # TODO: optimize this regexp
    name.downcase.sub!(/^.*::/, '').to_sym
  end
  
  def initialize(store)
    self.store = store
  end
  
  def ==(other)
    # due to our use of SHA-1, this _should_ fail in a reasonable and expected
    # manner when the other object isn't a Git object
    self.hash == other.hash
  end
  
  alias eql? ==
  
  def id
    self.class.id(type, dump)
  end
  
  alias hash id
  
  def save
    store.put(self.id, self.type, self.dump)
  end
  
  def type
    self.class.type
  end
  
  def canonical
    self.class.canonical(type, dump)
  end
  
  def load(dump)
    proxy!(dump) { _load(dump) }
    self
  end
  
  def dump
    _dump
  end
  
  def inspect
    "#<#{self.class.name} #{id}>"
  end
  
  def to_blob
    raise Git::ObjectTypeError,
      "#{type} can't be represented as a blob"
  end
  
  def to_tree
    raise Git::ObjectTypeError,
      "#{type} isn't tree-ish"
  end
  
  def to_commit
    raise Git::ObjectTypeError,
      "#{type} can't be represented as a commit"
  end
  
  private
  
  attr_accessor :store
  
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
  
  def self.cache
    OBJECT_CACHE
  end
end

require 'git/object/blob'
# require 'git/object/commit'
# require 'git/object/tree'
