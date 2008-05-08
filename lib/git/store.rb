require 'git/store/sha1file'

module Git::Store
  def self.find(hash)
    Git::Store::Sha1File.find(hash)
  end
end