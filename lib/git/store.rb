class Git::Store
  attr_reader :writer
  attr_reader :readers
  
  def initialize(git_path)
    self.writer   = Git::Store::LooseObject.new(git_path)
    self.readers  = [ self.writer ]
  end
  
  def get(id)
    # TODO: avoid looking first, just try them all
    readers.detect {|store| store.contains?(id) }.get(id)
  rescue NoMethodError => e
    raise e
    raise Git::ObjectNotFound, "not a valid object id '#{id}'"
  end
  
  def put(id, type, dump)
    writer.put(id, type, dump)
  end
  
  def contains?(id)
    not readers.detect {|store| store.contains?(id) }.nil?
  end
    
  private
  
  attr_writer :writer
  attr_writer :readers
end

require 'git/store/loose_object'