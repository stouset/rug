class Git::Object::Blob < Git::Object
  lazy_accessor :contents
  
  def initialize(contents = nil)
    self.contents = contents
  end
  
  private
  
  def _dump
    self.contents
  end
  
  def _load(dump)
    self.contents = dump
  end
end