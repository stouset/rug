#
# Represents a Blob. Blobs contain raw text data. In the case of files, they
# contain the raw, unformatted contents of the file. Symlinks are represented
# by a Blob containing only the filename of the symlink target.
#
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