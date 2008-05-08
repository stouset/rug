module Git::Store
  def self.create(object)
    Git::Store::LooseObject.create(object)
  end
  
  def self.find(hash)
    Git::Store::LooseObject.find(hash)
  end
end

require 'git/store/sha1_file'