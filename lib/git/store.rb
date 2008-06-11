#
# Proxies object storage to specific object backends, like the loose object
# store and pack files. Allows storing and retrieving objects while
# abstracting the real location and storage type of the objects themselves.
#
# Any type of store must implement the following interface:
#
# [<tt>Klass#initialize(git_path)</tt>]
#   Must set up the storage engine to read objects from the repository at
#   +git_path+.
#
# [<tt>Klass#contains?(id)</tt>]
#   Must return whether or not the object is currently contained in the
#   storage engine.
#
# [<tt>Klass#get(id)</tt>]
#   Must return an array of <tt>[type, dump]</tt> for the object if it exists.
#   If not, must return nil.
#
# [<tt>Klass#put(id, type, dump)</tt>]
#   Must store the object's +type+ and +dump+ in a way that can be later
#   retrieved by the +id+. Must return the id of the stored object.
#
# [<tt>Klass#disambiguate(id)</tt>]
#
class Git::Store
  #
  # Opens an existing store for the git repository at +git_path+.
  #
  def initialize(git_path)
    loose_object = Git::Store::LooseObject.new(git_path)
    
    self.readers    = [ loose_object ]
    self.writer     = loose_object
  end
  
  #
  # Returns whether or not the object identified by +id+ exists in any
  # permanent storage engine.
  #
  def contains?(id)
    readers.detect {|store| store.contains?(id) } != nil
  end
  
  def get(id)
    store = readers.detect {|store| store.contains?(id) }
    
    case store.nil?
      when false then store.get(id)
      else raise Git::ObjectNotFound, "couldn't find #{id}"
    end
  end
  
  def put(id, type, dump)
    writer.put(id, type, dump) unless contains?(id)
  end
  
  def disambiguate(id)
    ids = readers.map {|store| store.disambiguate(id) }.flatten.uniq
    
    case ids.length <=> 1
      when  0 then ids.first
      when -1 then raise Git::ObjectNotFound, "couldn't find #{id}"
      when  1 then raise Git::ObjectNotFound, "couldn't disambiguate #{id}"
    end
  end
    
  private
  
  # an array of permanent storage engines
  attr_accessor :readers
  
  # the storage engine to permanently write objects to
  attr_accessor :writer
end

require 'git/store/loose_object'