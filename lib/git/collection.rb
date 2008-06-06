class Git::Collection
  attr_accessor :repository
  attr_accessor :klass
  
  include Enumerable
  
  def initialize(store, klass)
    self.store = store
    self.klass = klass
  end
  
  def [](id)
    klass.find(store, id)
  end
  
  def each(&block)
    klass.each(store, &block)
  end
  
  def exists?
    klass.exists?(store)
  end
  
  def to_s
    to_a.to_s
  end
end