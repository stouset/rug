module Proxyable
  private
  
  def included(base)
    super
    base.extend(ClassMethods)
  end
  
  protected
  
  module ClassMethods
    protected
    
    def attr_proxy(*attrs)
      self.proxied_attributes ||= []
      self.proxied_attributes.push(*attrs)
      
      attr_accessor(*attrs)
    end
  end
  
  def proxy!(dump, &loader)
    metaclass = class << self; self; end
    metaclass.send(:alias_method,  :proxied_dump, :dump)
    metaclass.send(:define_method, :proxied_dump) { dump }
    metaclass.send(:define_method, :proxied_load, &loader)
    
    self.class.proxied_attributes.each do |a|
      metaclass.send(:alias_method,  :"proxied_#{a}",  :"#{a}")
      metaclass.send(:alias_method,  :"proxied_#{a}=", :"#{a}=")
      metaclass.send(:define_method, :"#{a}") { unproxy!; a }
      metaclass.send(:define_method, :"#{a}=") do |v|
        # only need to perform a load if we're not overwriting the thing
        unproxy!(self.class.proxied_attributes.length > 1)
        self.send(:"#{a}=", v)
    end
  end
  
  def unproxy!(load = true)
    # we'll need this for the load later
    dump = self.dump
    
    metaclass = class << self; self; end
    metaclass.send(:alias_method, :dump, :proxied_dump)
    
    self.class.proxied_attributes.each do |a|
      metaclass.send(:alias_method, :"#{a}",  :"proxied_#{a}")
      metaclass.send(:alias_method, :"#{a}=", :"proxied_#{a}=")
    end
      
    # perform the actual load
    proxied_load(dump) if load
  end
end