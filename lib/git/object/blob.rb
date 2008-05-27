class Git::Object::Blob < Git::Object
  attr_accessor :contents
  
  #
  # Creates a new instance of a Blob with optional raw +contents+.
  #
  def initialize(contents = nil)
    self.contents = contents
  end
  
  #
  # Pretty-printed output of the Blob contents.
  #
  def to_s
    contents
  end
  
  private
  
  def _dump
    self.contents
  end
  
  def _load(dump)
    self.contents = dump
  end
end