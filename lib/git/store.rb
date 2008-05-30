module Git::Store
  def self.create(type, hash, dump)
    Git::Store::LooseObject.create(type, hash, dump)
  end
  
  def self.find(hash)
    begin
      Git::Store::LooseObject.find(hash)
    end or raise Git::ObjectNotFound
  end
  
  def self.exists?(hash)
    Git::Store::LooseObject.exists?(hash)
  end
end

require 'git/store/loose_object'