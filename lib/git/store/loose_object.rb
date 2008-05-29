require 'digest/sha1'
require 'zlib'

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
# The only valid types of object which can be stored in the loose object
# format are enumerated in VALID_OBJECTS.
#
class Git::Store::LooseObject
  # default permissions on loose objects
  PERMS         = 0444
  
  # length of the subdirectory names
  SUBDIR_LENGTH = 2
  
  # regexp to match loose object format
  INPUT_FORMAT  = /^(\w+) (\d+)\0/
  
  # sprintf-compatible output format
  OUTPUT_FORMAT = "%s %d\0%s"
  
  # valid types for a loose object
  VALID_OBJECTS = [ :blob, :commit, :tree, :tag ]
  
  attr_accessor :hash
  attr_accessor :type
  attr_accessor :dump
  
  #
  # Instantiates and saves a new loose object, given the type of object, its
  # hash, and the dump of its contents.
  #
  def self.create(hash, type, dump)
    self.new(hash, type, dump).save
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
    match = read(hash).match(INPUT_FORMAT)
    
    # extract the header and contents of the file
    type   = match[1].to_sym
    length = match[2].to_i
    dump   = match.post_match
    
    verify_type(hash, type)
    verify_length(hash, length, dump)
    verify_hash(hash, type, dump)
    
    self.new(hash, type, dump)
  rescue Errno::ENOENT
    nil
  end
  
  #
  # Removes a loose object from disk by its hash identifier. Returns the hash
  # if there was a file matching the hash and it was successfully removed.
  # Returns nil if there was no file matching the hash identifier.
  #
  def self.destroy(hash)
    path(hash).unlink
    hash
  rescue Errno::ENOENT
    nil
  end
  
  #
  # Initializes a new loose object with the given object attributes. The type
  # is the type of the git object, hash is the SHA-1 hash of its canonical
  # form, and the dump is its raw dumped contents.
  #
  def initialize(hash, type, dump)
    self.hash = hash
    self.type = type
    self.dump = dump
  end
  
  #
  # Saves the contents of the object in a file on disk. Returns self. Raises
  # a CorruptLooseObject exception if the contents don't pass all validations.
  #
  def save
    unless saved?
      # TODO: decide whether or not I should perform validations like this at
      # save-time, or only read-time. They can be quite slow.
      self.class.verify_type(hash, type)
      self.class.verify_length(hash, length, dump)
      self.class.verify_hash(hash, type, dump)
      
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
    self.class.path(hash)
  end
  
  #
  # The length of the object's contents
  #
  def length
    dump.length
  end
  
  private
  
  #
  # Returns the entire contents of the file with the given hash.
  #
  def self.read(hash)
    Zlib::Inflate.inflate( path(hash).read )
  end
  
  #
  # Writes out the contents to a file. Needs the +hash+ to identify the file
  # and the +contents+ to write. BE CAREFUL. This method does not validate the
  # contents against the hash, so please be certain you're writing valid data.
  #
  def self.write(hash, contents)
    path = self.path(hash)
    path.dirname.mkpath
    path.open('w', PERMS) do |f|
      f.write Zlib::Deflate.deflate(contents)
    end
  end
  
  #
  # Returns the path associated with a given hash.
  #
  def self.path(hash)
    name = hash.dup.insert(SUBDIR_LENGTH, File::SEPARATOR)
    Git::Repository.object_path(name)
  end
  
  #
  # Checks whether or not a file exists with the given hash.
  #
  def self.exists?(hash)
    path(hash).exist?
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
  def self.verify_length(hash, length, dump)
    if length != dump.length
      raise Git::CorruptLooseObject, "contents of #{hash} had the wrong length"
    end
  end
  
  #
  # Raises an exception if the hash of an object doesn't match the hash
  # passed.
  #
  def self.verify_hash(hash, type, dump)
    if hash != Git::Object.hash(type, dump)
      raise Git::CorruptLooseObject, "contents of #{hash} did not match hash"
    end
  end
end