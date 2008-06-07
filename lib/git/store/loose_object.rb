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
  # location of the object store
  OBJECT_PATH = 'objects'
  
  # default permissions on loose objects
  PERMS = 0444
  
  # length of the subdirectory names
  SUBDIR_LENGTH = 2
  
  # regexp to match loose object format
  INPUT_FORMAT = /^(\w+) (\d+)\0/
  
  # sprintf-compatible output format
  OUTPUT_FORMAT = "%s %d\0%s"
  
  # valid types for a loose object
  VALID_OBJECTS = [ :blob, :commit, :tree, :tag ]
  
  attr_accessor :path
  
  def initialize(git_path)
    self.path = git_path.join(OBJECT_PATH)
  end
  
  def contains?(id)
    path_to(id).exists?
  end
  
  #
  # Looks up a loose object by its hash. Performs all validation possible
  # without actually loading the object into memory. Returns the loose object
  # if it was found, and nil if not.
  #
  # Raises a CorruptLooseObject exception if the file contains any
  # discrepancies, such as an incorrect length or inappropriate type.
  #
  def get(id)
    match = read(id).match(INPUT_FORMAT)
    
    # extract the header and contents of the file
    type   = match[1].to_sym
    length = match[2].to_i
    dump   = match.post_match
    
    verify_type(id, type)
    verify_length(id, length, dump)
    verify_id(id, type, dump)
    
    [type, dump]
  rescue Errno::ENOENT
    nil
  end
  
  def put(id, type, dump)
    unless contains?(id)
      # TODO: decide whether or not I should perform validations like this at
      # save-time, or only read-time; they may be slow.
      verify_type(id, type)
      verify_id(id, type, dump)
      
      contents = OUTPUT_FORMAT % [ type, length, dump ]
      
      write(id, contents)
    end
    
    id
  end
  
  def delete(id)
    path_to(id).unlink
    id
  rescue Errno::ENOENT
    nil
  end
  
  private
  
  #
  # Returns the entire contents of the file with the given hash.
  #
  def read(id)
    Zlib::Inflate.inflate( path_to(id).read )
  end
  
  #
  # Writes out the contents to a file. Needs the +hash+ to identify the file
  # and the +contents+ to write. BE CAREFUL. This method does not validate the
  # contents against the hash, so please be certain you're writing valid data.
  #
  def write(id, contents)
    path = path_to(id)
    path.dirname.mkpath
    path.open('w', PERMS) do |f|
      f.write Zlib::Deflate.deflate(contents)
    end
  end
  
  def path_to(id)
    path.join id.dup.insert(SUBDIR_LENGTH, File::SEPARATOR)
  end
  
  #
  # Raises an exception if +type+ can't be contained in a loose object.
  #
  def verify_type(id, type)
    unless VALID_OBJECTS.include? type
      raise Git::CorruptLooseObject, "contents of #{id} can't be a #{type}"
    end
  end
  
  #
  # Raises an exception if the length of data doesn't match the specified
  # length.
  #
  def verify_length(id, length, dump)
    if length != dump.length
      raise Git::CorruptLooseObject, "contents of #{id} have bad length"
    end
  end
  
  #
  # Raises an exception if the id of an object doesn't match the id
  # passed.
  #
  def verify_id(id, type, dump)
    if id != Git::Object.id(type, dump)
      raise Git::CorruptLooseObject, "contents of #{id} do not match id"
    end
  end
end
