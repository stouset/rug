require 'digest/sha1'
require 'zlib'

require 'fileutils'

#
# Stores Git::Objects on disk inside a file named according to the SHA1 hash
# of their contents. This inherently provides easy checks to prevent silent
# data corruption, and uses the disk like a giant hashtable, letting us store
# and retrieve contents by a key related to their contents.
#
# The contents of each file are compressed using zlib. The name of the file is
# the SHA1 hash of the uncompressed contents, with a directory separator after
# the first two characters of the hash.
#
# The uncompressed contents of the file are stored in the format:
#
#   "#{type} #{length}\0#{data}"
#
# The entire rest of the file after the first ASCII NUL are the contents of
# the Git::Object, whose format is specified on a per-object-type basis (check
# the docs for any relevand Git::Object subclasses).
#
class Git::Store::Sha1File
  PATH          = 'objects' # path within the git repository for Sha1Files
  PERMS         = 0444      # default permissions on Sha1Files
  SUBDIR_LENGTH = 2         # length of the subdirectory names
  
  INPUT_FORMAT  = /(\w+) (\d+)\0(.*)/m  # regexp to match files on input
  OUTPUT_FORMAT = "%s %d\0%s"           # printf-compatible string for output
  
  VALID_OBJECTS = %w{ blob commit tree tag } # valid types inside a Sha1File
  
  attr_accessor :object
  
  #
  # Joins all +parts+ of the path, relative to the SHA-1 file root.
  #
  def self.path(*parts)
    Git.path(PATH, *parts)
  end
  
  #
  # Instantiates and saves a new Sha1File with the contents of a Git::Object.
  #
  def self.create(object)
    self.new(object).save
  end
  
  #
  # Finds a Sha1File by its hash. Loads the object into memory and peforms any
  # necessary validation. Will return the Sha1File for that object if it
  # exists, and nil if not.
  #
  # Raises a CorruptSha1File exception if the file contains any discrepancies,
  # such as a non-matching hash, incorrect length, or an invalid type.
  #
  def self.find(hash)
    # exit early if there's no file
    return nil unless self.exists?(hash)
    
    contents = read(hash)
    
    verify_hash(hash, contents)
    
    # extract the contents of the file
    match  = contents.match(INPUT_FORMAT)
    type   = match[1]
    length = match[2].to_i
    data   = match[3]
    
    verify_type(hash, type)
    verify_length(hash, data, length)
    
    # instantiate a new Sha1File using the retrieved object
    self.new(Git::Object.load(type, data))
  end
  
  #
  # Removes a Sha1File from disk by its hash identifier. Returns true if there
  # was a file matching the hash and it was successfully removed. Returns false
  # if there was no file matching the hash identifier.
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
  # Initializes a new Sha1File with the given Git::Object. Does not save the
  # file.
  #
  def initialize(object)
    self.object = object
  end
  
  #
  # Saves the contents of the object in a file on disk. Returns self.
  #
  def save
    unless saved?
      self.class.write(hash, contents)
    end
    
    self
  end
  
  #
  # Removes the Sha1File's disk entry. Returns self.
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
  # Returns the filename of the Sha1File, based on its current contents.
  #
  def filename
    self.class.filename(hash)
  end
  
  #
  # Returns the uncompressed contents of the Sha1File as seen on disk.
  #
  def contents
    type   = object.type
    data   = object.dump
    length = data.length
    
    OUTPUT_FORMAT % [type, length, data]
  end
  
  #
  # Calculates the SHA1 hash of the object's contents.
  #
  def hash
    self.class.hash(contents)
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
  # Writes out data to the file with the given hash. BE CAREFUL. This method
  # does not check the hash against the data being sent. It assumes that you,
  # the caller, have done your homework.
  #
  def self.write(hash, data)
    path = self.filename(hash)
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, 'w', PERMS) do |f|
      f.write Zlib::Deflate.deflate(data)
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
  # Performs the SHA1 hash against a blob of data.
  #
  def self.hash(data)
    Digest::SHA1.hexdigest(data)
  end
  
  #
  # Checks whether or not a file exists with the given hash.
  #
  def self.exists?(hash)
    File.exist?(self.filename(hash))
  end
  
  #
  # Raises an exception if +hash+ doesn't correctly describe the contents of
  # +data+.
  #
  def self.verify_hash(hash, data)
    if self.hash(data) != hash
      raise Git::CorruptSha1File, "contents of #{hash} didn't match checksum"
    end
  end
  
  #
  # Raises an exception if +type+ isn't valid to be contained in a Sha1File.
  #
  def self.verify_type(hash, type)
    unless VALID_OBJECTS.include? type
      raise Git::CorruptSha1File, "contents of #{hash} can't be a #{type}"
    end
  end
  
  #
  # Raises an exception if the length of data doesn't match the specified
  # length.
  #
  def self.verify_length(hash, data, length)
    if data.length != length
      raise Git::CorruptSha1File, "contents of #{hash} had the wrong length"
    end
  end
end