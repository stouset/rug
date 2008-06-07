class Git::Collection
  attr_accessor :store
  attr_accessor :klass
  
  include Enumerable
  
  def initialize(store, klass)
    self.store = store
    self.klass = klass
  end
  
  def [](id)
    klass.find(store, id)
  end
  
  def create(*args)
    klass.create(store, *args)
  end
  
  def new(*args)
    klass.new(store, *args)
  end
  
  def each(&block)
    klass.each(store, &block)
  end
  
  def contains?(id)
    store.contains?(id)
  end
  
  def to_s
    to_a.to_s
  end
end