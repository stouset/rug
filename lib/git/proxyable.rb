module Proxyable
  private
  
  def self.included(base)
    super
    base.extend(ClassMethods)
  end
  
  protected
  
  module ClassMethods
    protected
    
    attr_accessor :proxied_attributes
    
    def attr_proxied(*attrs)
      self.proxied_attributes ||= []
      self.proxied_attributes.push(*attrs)
      
      attr_accessor(*attrs)
    end
  end
  
  def proxy!(dump, &loader)
    metaclass = class << self; self; end
    metaclass.send(:define_method, :proxied_load, &loader)
    metaclass.send(:alias_method,  :proxied_dump, :_dump)
    metaclass.send(:define_method, :_dump) { dump }
    
    self.class.proxied_attributes.each do |a|
      metaclass.send(:alias_method,  :"proxied_#{a}",  :"#{a}")
      metaclass.send(:alias_method,  :"proxied_#{a}=", :"#{a}=")
      metaclass.send(:define_method, :"#{a}") { unproxy!; self.send(a) }
      metaclass.send(:define_method, :"#{a}=") do |v|
        # only need to perform a load if we're not overwriting the thing
        unproxy!(self.class.proxied_attributes.length > 1)
        self.send(:"#{a}=", v)
      end
    end
  end
  
  def unproxy!(load = true)
    metaclass = class << self; self; end
    metaclass.send(:alias_method, :_dump, :proxied_dump)
    
    self.class.proxied_attributes.each do |a|
      metaclass.send(:alias_method, :"#{a}",  :"proxied_#{a}")
      metaclass.send(:alias_method, :"#{a}=", :"proxied_#{a}=")
    end
      
    # perform the actual load
    proxied_load if load
  end
end