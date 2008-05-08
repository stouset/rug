module Git::Store
  def self.find(hash)
    Git::Store::Sha1File.find(hash)
  end
end

require 'git/store/sha1_file'