module Git::Store
  def self.create(type, hash, dump)
    Git::Store::LooseObject.create(type, hash, dump)
  end
  
  def self.find(hash)
    Git::Store::LooseObject.find(hash)
  end
end

require 'git/store/loose_object'