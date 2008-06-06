class Git::Collection
  attr_accessor :repo
  attr_accessor :klass
  
  include Enumerable
  
  def initialize(repo, klass)
    self.repo  = repo
    self.klass = klass
  end
  
  def [](id)
    klass[repo, id]
  end
  
  def find(*args)
    klass.find(repo, *args)
  end
  
  def find_all(*args)
    klass.find_all(repo, *args)
  end
  
  def each(&block)
    to_a.each(&block)
  end
  
  def to_a
    klass.find_all(repo)
  end
  
  def to_s
    to_a.to_s
  end
end