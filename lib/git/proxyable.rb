#
# Inclusion of this module implies that an object can have its instantiation
# delayed until proxied attributes are called. This is important to prevent an
# avalanche effect, where loading one object causes all its children to load,
# recusively.
#
# To defer loading an object, include Git::Proxyable, then wrap the
# <tt>_load</tt> method in a <tt>proxy!</tt> block.
#
#   def _load(dump)
#     proxy!(dump) do
#       # loading code
#       ...
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
    attr_accessor :proxied_attributes
    
    protected
    
    #
    # Declare a proxyable attribute.
    #
    def attr_proxied(*attrs)
      self.proxied_attributes ||= []
      self.proxied_attributes  |= attrs
      
      attr_accessor(*attrs)
    end
  end
  
  protected
  
  #
  # Call this method to proxy all +proxied_attributes+. Takes the +dump+ of
  # the object's contents to load later, and a block that performs the actual
  # deferred load.
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
        # only need to perform a load if we're not overwriting the thing
        unproxy!(self.class.proxied_attributes.length > 1)
        self.send("#{a}=".to_sym, v)
      end
    end
  end
  
  private
  
  #
  # Forces the Object to finish loading, and unproxies all proxied attributes.
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