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
# the SHA-1 hash of the uncompressed contents, with a directory separator after
# the first two characters of the hash.
#
# Once uncompressed, the contents of the file are stored in the format:
#
#   "#{type} #{length}\0#{data}"
#
# The entire rest of the file after the first ASCII NUL are the contents of
# the Git::Object, whose format is specified on a per-object-type basis (check
# the docs for any relevand Git::Object subclasses).
#
class Git::Store::LooseObject
  PATH          = 'objects' # path within the git repository for loose objects
  PERMS         = 0444      # default permissions on loose objects
  SUBDIR_LENGTH = 2         # length of the subdirectory names
  
  INPUT_FORMAT  = /(\w+) (\d+)\0(.*)/m  # regexp to match canonical input
  OUTPUT_FORMAT = "%s %d\0%s"           # sprintf-compatible output format
  
  VALID_OBJECTS = %w{ blob commit tree tag } # valid types for a loose object
  
  attr_accessor :object
  
  #
  # Joins all +parts+ of the path, relative to the loose object root.
  #
  def self.path(*parts)
    Git.path(PATH, *parts)
  end
  
  #
  # Instantiates and saves a new loose object with the contents of the
  # Git::Object passed.
  #
  def self.create(object)
    self.new(object).save
  end
  
  #
  # Finds a loose object by its hash. Loads the object into memory and peforms
  # any necessary validation. Will return the loose object for that hash if it
  # exists, and nil if not.
  #
  # Raises a CorruptLooseObject exception if the file contains any
  # discrepancies, such as a non-matching hash, incorrect length, or an
  # invalid type.
  #
  def self.find(hash)
    # exit early if there's no file
    return nil unless self.exists?(hash)
    
    contents = read(hash)
    
    # extract the header and contents of the file
    match  = contents.match(INPUT_FORMAT)
    type   = match[1]
    length = match[2].to_i
    data   = match[3]
    
    verify_type(hash, type)
    verify_length(hash, data, length)
    
    # instantiate the object with its type and data
    object = Git::Object.load(type, data)
    
    verify_object_hash(hash, object)
    
    # instantiate one of ourselves using the fresh object
    self.new(object)
  end
  
  #
  # Removes a loose object from disk by its hash identifier. Returns true if
  # there was a file matching the hash and it was successfully removed.
  # Returns false if there was no file matching the hash identifier.
  #
  def self.destroy(hash)
    if self.exists?(hash)
      File.unlink(self.filename(hash))
      true
    else
      false
    end
  end
  
  #
  # Initializes a new loose object with the given Git::Object. Does not
  # automatically save the file.
  #
  def initialize(object)
    self.object = object
  end
  
  #
  # Saves the contents of the object in a file on disk. Returns self.
  #
  def save
    unless saved?
      self.class.verify_type(hash, object.type)
      
      type     = object.type
      data     = object.dump
      contents = OUTPUT_FORMAT % [ type, data.length, data ]
      
      self.class.write(object.hash, contents)
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
  # Returns whether or not there is already a file on disk whose contents match
  # those of the current object.
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
  # The SHA-1 hash of the file's contents.
  #
  def hash
    object.hash
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
  def self.verify_length(hash, data, length)
    if data.length != length
      raise Git::CorruptLooseObject, "contents of #{hash} had the wrong length"
    end
  end
  
  #
  # Raises an exception if +hash+ doesn't correctly describe the contents of
  # +data+.
  #
  def self.verify_object_hash(hash, object)
    if object.hash != hash
      raise Git::CorruptLooseObject, "contents of #{hash} didn't match hash"
    end
  end
end