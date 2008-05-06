module Git
  GIT_DIR = '.git'
  
  def self.path(*parts)
    File.join(GIT_DIR, *parts)
  end
end