#
# Inclusion of this module implies that an object can have its instantiation
# delayed until proxied attributes are called. This is important to prevent an
# avalanche effect, where loading one object causes all its children to load,
# recusively.
#
# To defer loading an object, include Git::Proxyable, define your attributes
# using attr_proxyable, then wrap your <tt>_load</tt> method in a
# <tt>proxy!</tt> block.
#
#   class Git::Object::Foo < Git::Object
#     include Git::Proxyable
#
#     attr_proxied :a
#     attr_proxied :b
#
#     private
#
#     def _load(dump)
#       proxy!(dump) do
#         # assign a and b here
#         ...
#       end
#     end
#   end
#
# This will cause your Object to defer parsing its dump file until any method
# defined with +attr_proxied+ is called, at which point the block will run and
# the Object will become fully loaded.
#
module Git::Proxyable
  private
  
  def self.included(base)
    super
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    #
    # The list of proxied attributes.
    #
    def proxied_attributes
      @proxied_attributes ||= []
    end
    
    protected
    
    #
    # Declare a proxyable attribute.
    #
    def attr_proxied(*attrs)
      self.proxied_attributes.push(*attrs)
      self.proxied_attributes.uniq!
      attr_accessor(*attrs)
    end
  end
  
  protected
  
  #
  # Call this method to proxy all +proxied_attributes+. Takes the +dump+ of
  # the object's contents to load later, and a block that performs the actual
  # deferred load.
  #
  # Will rewrite the _inspect_ method to hide instance variables, the
  # _dump method to return the exact contents of the +dump+ passed, and all
  # +proxied_attributes+ to perform the load before returning their new
  # contents.
  #
  def proxy!(dump, &loader)
    metaclass = class << self; self; end
    metaclass.send(:define_method, :proxied_load, &loader)
    metaclass.send(:alias_method,  :proxied_dump, :_dump)
    metaclass.send(:define_method, :_dump) { dump }
    
    metaclass.send(:alias_method,  :proxied_inspect, :inspect)
    metaclass.send(:define_method, :inspect) do
      "#<#{self.class.name}:#{self.object_id.to_s(16)} (proxied)>"
    end
    
    self.class.proxied_attributes.each do |a|
      metaclass.send(:alias_method,  "proxied_#{a}".to_sym,  "#{a}".to_sym)
      metaclass.send(:alias_method,  "proxied_#{a}=".to_sym, "#{a}=".to_sym)
      metaclass.send(:define_method, "#{a}".to_sym) { unproxy!; self.send(a) }
      metaclass.send(:define_method, "#{a}=".to_sym) do |v|
        # only need to perform a load if we're not overwriting the whole thing
        unproxy!(self.class.proxied_attributes.length > 1)
        self.send("#{a}=".to_sym, v)
      end
    end
  end
  
  private
  
  #
  # Forces the Object to finish loading, and unproxies all proxied attributes.
  # 
  # If +load+ is false, does not perform the deferred load. This might be
  # preferred in the case of an object with one +proxied_attribute+ that's
  # unproxied due to its attribute being overwritten. In such a case, there's
  # no reason to parse its dump, since the contents will just be modified
  # anyway.
  #
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