require 'digest/sha1'
require 'zlib'

require 'fileutils'

class Git::Store::Sha1File
  PATH          = 'objects'
  
  PERMS         = 0444
  SUBDIR_LENGTH = 2
  
  INPUT_FORMAT  = /(\w+) (\d+)\0(.*)/
  OUTPUT_FORMAT = "%s %d\0%s"
  
  
  attr_accessor :object
  
  #
  # Joins all +parts+ of the path, relative to the SHA-1 file root.
  #
  def self.path(*parts)
    Git.path(PATH, *parts)
  end
  
  def self.create(object)
    self.new(object).save
  end
  
  #
  # Finds a Sha1File by its hash. Loads the object into memory and peforms any
  # necessary validation.
  #
  def self.find(hash)
    contents = read(hash)
    
    verify_hash(contents, hash)
    
    match  = contents.match(FILE_FORMAT)
    type   = match[1].capitalize
    length = match[2].to_i
    data   = match[3]
    
    verify_length(data, length)
    
    self.new(nil)
  rescue Errno::ENOENT
    nil
  end
  
  def self.destroy(hash)
    File.unlink(self.filename(hash))
    true
  rescue Errno::ENOENT
    false
  end
  
  def initialize(object)
    self.object = object
  end
  
  def save
    unless saved?
      self.class.write(hash, contents)
    end
    
    self
  end
  
  def destroy
    self.class.destroy(self.hash)
    self
  end
  
  def saved?
    self.class.exists?(self.hash)
  end
  
  def filename
    self.class.filename(hash)
  end
  
  def contents
    type   = object.type
    data   = object.dump
    length = data.length
    
    OUTPUT_FORMAT % [type, length, data]
  end
  
  def hash
    self.class.hash(contents)
  end
  
  private
  
  def self.read(hash)
    path = self.filename(hash)
    Zlib::Inflate.inflate( File.read( path ) )
  end
  
  def self.write(hash, data)
    path = self.filename(hash)
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, 'w', PERMS) do |f|
      f.write Zlib::Deflate.deflate(data)
    end
  end
  
  def self.filename(hash)
    self.path(hash.dup.insert(SUBDIR_LENGTH, File::SEPARATOR))
  end
  
  def self.hash(data)
    Digest::SHA1.hexdigest(data)
  end
  
  def self.exists?(hash)
    File.exist?(self.filename(hash))
  end
  
  def self.verify_hash(data, hash)
    if self.hash(data) != hash
      raise Git::CorruptSha1File, "contents of #{hash} didn't match checksum"
    end
  end
  
  def self.verify_length(data, length)
    if data.length != length
      raise Git::CorruptSha1File, "contents of #{hash} had the wrong length"
    end
  end
end