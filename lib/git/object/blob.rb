#
# Represents a Blob. Blobs contain raw text data. In the case of files, they
# contain the raw, unformatted contents of the file. Symlinks are represented
# by a Blob containing only the filename of the symlink target.
#
# Blobs do not, by themselves, contain any semantic meaning. The same blob
# might be pointed to by different filenames across different commits, as long
# as both contain the exact same contents. This allows content to never be
# duplicated within a repository.
#
class Git::Object::Blob < Git::Object
  attr_accessor :contents
  
  #
  # Creates a new instance of a Blob with optional raw +contents+.
  #
  def initialize(store, contents = nil)
    self.contents = contents
    super(store)
  end
  
  #
  # Pretty-printed output of the Blob contents. Since Blobs are just raw text
  # data, simply returns the raw text.
  #
  def to_s
    contents.to_s
  end
  
  def to_blob
    self
  end
  
  private
  
  #
  # Loads the blob from a raw dump. Since blobs are raw text, does not need
  # to do any parsing or formatting.
  #
  def _load(dump)
    self.contents = dump
  end
  
  #
  # Returns the raw contents of the blob.
  #
  def _dump
    self.contents
  end
end