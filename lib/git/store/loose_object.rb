require 'digest/sha1'
require 'zlib'

require 'fileutils'

#
# Stores Git::Objects on disk inside a file named according to the SHA-1 hash
# of their canonical form. This inherently provides easy checks to prevent
# silent data corruption, and uses the disk like a giant hashtable, letting us
# store and retrieve contents by a key related to their contents.
#
# The contents of each file are compressed using zlib. The name of the file is
# the SHA-1 hash of the uncompressed contents, with a directory separator
# after the first two characters of the hash.
#
# Once uncompressed, the contents of the file are stored in the format:
#
#   "#{type} #{length}\0#{dump}"
#
# The entire rest of the file after the first ASCII NUL are the contents of
# the Git::Object, whose format is specified on a per-object-type basis (check
# the docs for any relevant Git::Object subclasses).
#
class Git::Store::LooseObject
  PATH          = 'objects' # path within the git repository for loose objects
  PERMS         = 0444      # default permissions on loose objects
  SUBDIR_LENGTH = 2         # length of the subdirectory names
  
  INPUT_FORMAT  = /(\w+) (\d+)\0(.*)/m  # regexp to match canonical input
  OUTPUT_FORMAT = "%s %d\0%s"           # sprintf-compatible output format
  
  VALID_OBJECTS = %w{ blob commit tree tag } # valid types for a loose object
  
  attr_accessor :type
  attr_accessor :hash
  attr_accessor :dump
  
  #
  # Joins all +parts+ of the path, relative to the loose object root.
  #
  def self.path(*parts)
    Git.path(PATH, *parts)
  end
  
  #
  # Instantiates and saves a new loose object, given the type of object, its
  # hash, and the dump of its contents.
  #
  def self.create(type, hash, dump)
    self.new(type, hash, dump).save
  end
  
  #
  # Looks up a loose object by its hash. Performs all validation possible
  # without actually loading the object into memory. Returns the loose object
  # if it was found, and nil if not.
  #
  # Raises a CorruptLooseObject exception if the file contains any
  # discrepancies, such as an incorrect length or inappropriate type.
  #
  def self.find(hash)
    # exit early if there's no file
    return nil unless self.exists?(hash)
    
    contents = read(hash)
    
    # extract the header and contents of the file
    match  = contents.match(INPUT_FORMAT)
    type   = match[1]
    length = match[2].to_i
    dump   = match[3] 
    
    verify_type(hash, type)
    verify_length(hash, dump, length)
    
    self.new(type, hash, dump)
  end
  
  #
  # Removes a loose object from disk by its hash identifier. Returns the hash
  # if there was a file matching the hash and it was successfully removed.
  # Returns nil if there was no file matching the hash identifier.
  #
  def self.destroy(hash)
    if self.exists?(hash)
      File.unlink(self.filename(hash))
      hash
    end
  end
  
  #
  # Initializes a new loose object with the given object attributes. The type
  # is the type of the git object, hash is the SHA-1 hash of its canonical
  # form, and the dump is its raw dumped contents.
  #
  def initialize(type, hash, dump)
    self.type = type
    self.hash = hash
    self.dump = dump
  end
  
  #
  # Saves the contents of the object in a file on disk. Returns self.
  #
  def save
    unless saved?
      self.class.verify_type(hash, type)
      
      contents = OUTPUT_FORMAT % [ type, length, dump ]
      
      self.class.write(hash, contents)
    end
    
    self
  end
  
  #
  # Removes the loose object's disk entry. Returns self.
  #
  def destroy
    self.class.destroy(self.hash)
    self
  end
  
  #
  # Returns whether or not there is already a file on disk whose contents
  # match those of the current object.
  #
  # NOTE: Does NOT check to see if the file exists in other storage engines.
  #
  def saved?
    self.class.exists?(self.hash)
  end
  
  #
  # Returns the filename of the loose object, based on its current contents.
  #
  def filename
    self.class.filename(hash)
  end
  
  #
  # The length of the object's contents
  #
  def length
    dump.length
  end
  
  #
  # The Git::Object represented in the loose object. Is lazily constructed
  # only once this method is called. Validation is called to ensure the hash
  # of the object matches the one on disk.
  #
  # NOTE: Calling this method is preferred over loading the object yourself
  # using the accessors of the loose object, since this provides extra error
  # checking against the object hash. However, repeated use of this method may
  # be slow, since each call forces it to re-instantiate a new Git::Object.
  # We do not cache the results, since they may change if you alter the type
  # or contents of the loose object between calls.
  #
  def object
    object = Git::Object.load(type, dump)
    
    self.class.verify_object_hash(hash, object)
    
    object
  end
  
  private
  
  #
  # Returns the entire contents of the file with the given hash.
  #
  def self.read(hash)
    path = self.filename(hash)
    Zlib::Inflate.inflate( File.read( path ) )
  end
  
  #
  # Writes out the contents to a file. Needs the +hash+ to identify the file
  # and the +contents+ to write. BE CAREFUL. This method does not validate the
  # contents against the hash, so please be certain you're writing valid data.
  #
  def self.write(hash, contents)
    path = self.filename(hash)
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, 'w', PERMS) do |f|
      f.write Zlib::Deflate.deflate(contents)
    end
  end
  
  #
  # Returns the filename associated with a given hash.
  #
  def self.filename(hash)
    subdir   = hash[0, SUBDIR_LENGTH]
    filename = hash[SUBDIR_LENGTH .. -1]
    self.path(subdir.to_s, filename.to_s)
  end
  
  #
  # Checks whether or not a file exists with the given hash.
  #
  def self.exists?(hash)
    File.exist?(self.filename(hash))
  end
  
  #
  # Raises an exception if +type+ can't be contained in a loose object.
  #
  def self.verify_type(hash, type)
    unless VALID_OBJECTS.include? type
      raise Git::CorruptLooseObject, "contents of #{hash} can't be a #{type}"
    end
  end
  
  #
  # Raises an exception if the length of data doesn't match the specified
  # length.
  #
  def self.verify_length(hash, dump, length)
    if dump.length != length
      raise Git::CorruptLooseObject, "contents of #{hash} had the wrong length"
    end
  end
  
  #
  # Raises an exception if the hash of an object doesn't match the hash
  # passed.
  #
  def self.verify_object_hash(hash, object)
    if hash != object.hash
      raise Git::CorruptLooseObject, "contents of #{hash} did not match hash"
    end
  end
end