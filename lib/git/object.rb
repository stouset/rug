require 'digest/sha1'

class Git::Object
  CANONICAL_FORMAT = "%s %d\0%s"
  
  class << self
    attr_accessor :lazy_attributes
  end
  
  def self.find(hash)
    store  = Git::Store.find(hash)
    object = store && store.object
    
    verify_object_type(object) if object
    
    object
  end
  
  def self.lazy(type, hash)
    if Git::Store.exists?(hash)
      klass  = get_klass(type)
      object = klass.new
      
      object.send :proxy_lazy_attributes!, hash
      
      object
    end
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
  
  protected
  
  def self.lazy_accessor(*names)
    self.lazy_attributes ||= []
    self.lazy_attributes  += names
    self.lazy_attributes  += names.map {|name| "#{name}=".to_sym }
    
    attr_accessor *names
  end
  
  def proxy_lazy_attributes!(hash)
    attributes = self.class.lazy_attributes || []
    metaclass  = class << self; self; end
    
    metaclass.send :define_method, :retrieve_self_from_store do
      store = Git::Store.find(hash)
      name  = get_method_name
      
      self.send(:unproxy_lazy_attributes!)
      self.load(store.dump)
      store.class.send(:verify_object_hash, hash, self)
    end
    
    attributes.each do |name|      
      metaclass.send :alias_method, "lazy_#{name}".to_sym, name
      metaclass.send :define_method, name do |*args|
        retrieve_self_from_store
        self.send(name, *args)
      end
    end
  end
  
  def unproxy_lazy_attributes!
    attributes = self.class.lazy_attributes || []
    metaclass  = class << self; self; end
    
    attributes.each do |name|
      metaclass.send :alias_method, name, "lazy_#{name}".to_sym
    end
  end
  
  def get_method_name
    caller[0].match(/`([^']+)/).captures[0]
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