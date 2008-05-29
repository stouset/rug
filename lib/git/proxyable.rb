require 'set'

module Proxyable
  private
  
  def self.included(base)
    super
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    attr_accessor :proxied_attributes
    
    protected
    
    def attr_proxied(*attrs)
      self.proxied_attributes ||= Set.new
      self.proxied_attributes  |= attrs
      
      attr_accessor(*attrs)
    end
  end
  
  protected
  
  def proxy!(dump, &loader)
    metaclass = class << self; self; end
    metaclass.send(:define_method, :proxied_load, &loader)
    metaclass.send(:alias_method,  :proxied_dump, :_dump)
    metaclass.send(:define_method, :_dump) { dump }
    
    metaclass.send(:alias_method,  :proxied_inspect, :inspect)
    metaclass.send(:define_method, :inspect) do
      %{ #<#{self.class.name}:#{self.object_id.to_s(16)} (proxied)> }
    end
    
    self.class.proxied_attributes.each do |a|
      metaclass.send(:alias_method,  "proxied_#{a}".to_sym,  "#{a}".to_sym)
      metaclass.send(:alias_method,  "proxied_#{a}=".to_sym, "#{a}=".to_sym)
      metaclass.send(:define_method, "#{a}".to_sym) { unproxy!; self.send(a) }
      metaclass.send(:define_method, "#{a}=".to_sym) do |v|
        # only need to perform a load if we're not overwriting the thing
        unproxy!(self.class.proxied_attributes.length > 1)
        self.send("#{a}=".to_sym, v)
      end
    end
  end
  
  def unproxy!(load = true)
    metaclass = class << self; self; end
    metaclass.send(:alias_method, :_dump, :proxied_dump)
    metaclass.send(:alias_method, :inspect, :proxied_inspect)
    
    self.class.proxied_attributes.each do |a|
      metaclass.send(:alias_method, "#{a}".to_sym,  "proxied_#{a}".to_sym)
      metaclass.send(:alias_method, "#{a}=".to_sym, "proxied_#{a}=".to_sym)
    end
      
    # perform the actual load
    proxied_load if load
  end
end