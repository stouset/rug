module Git::LazyObject
  def lazy(type, hash)
    if Git::Store.exists?(hash)
      klass       = get_klass(type)
      object      = klass.new
      attributes  = object.class.lazy_attributes || []
      
      attributes.each do |name|
        metaclass = class << object; self; end
        metaclass.send :alias_method, "lazy_#{name}", name
        metaclass.send :define_method, name do
          store = Git::Store.find(hash)
          self.load(store.dump)
          meta = class << self; self; end
          meta.send :alias_method, name, "lazy_#{name}"
          self.send name
        end
      end
      
      object
    end
  end
  
  def lazy_accessor(*names)
    self.lazy_attributes ||= []
    self.lazy_attributes  += names
    
    attr_accessor *names
  end
  
  attr_accessor :lazy_attributes
end