class Git::Object::Blob < Git::Object
  attr_accessor :contents
  
  def self.load(data)
    self.new(data)
  end
  
  def initialize(contents)
    self.contents = contents
  end
  
  private
  
  def _dump
    self.contents
  end
end