class Git::Collection
  attr_accessor :store
  attr_accessor :klass
  
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
  
  def contains?(id)
    store.contains?(id)
  end
  
  alias contain?  contains?
  alias include?  contains?
  alias includes? contains?
end