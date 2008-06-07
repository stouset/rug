class Git::Repository
  # The location of the git dir in a repo
  GIT_DIR = '.git'
  
  #
  # Creates a git repository at +dir+.
  #
  def self.create(dir = Dir.pwd)
    new(dir).init!
  end
  
  #
  # Returns the repository that owns +dir+. Raises a Git::RepositoryNotFound
  # exception if the directory isn't owned by a git repository.
  #
  def initialize(dir = Dir.pwd)
    self.work_path = dir
  end
  
  def [](id)
    objects[id]
  end
  
  def objects
    @objects ||= Git::Collection.new(store, Git::Object)
  end
  
  def blobs
    @blobs ||= Git::Collection.new(store, Git::Blob)
  end
  
  def trees
    @trees ||= Git::Collection.new(store, Git::Tree)
  end
  
  def commits
    @commits ||= Git::Collection.new(store, Git::Commit)
  end
  
  def store
    @store ||= Git::Store.new(git_path)
  end
  
  #
  # Gets the location of the repository's working dir.
  #
  def work_path
    @work_path
  end
  
  #
  # Gets the location of the repository's git dir.
  #
  def git_path
    @git_path ||= work_path.join(GIT_DIR)
  end
  
  private
  
  #
  # Sets the working dir of the repository. Should not be modified once
  # written.
  #--
  # TODO: raise exception on re-modification
  #
  def work_path=(dir)
    @work_path = self.class.find_work_path(dir.to_path).absolute
  end
  
  #
  # Ascends up +path+ finding the top level of the working directory
  # containing +path+. Raises a Git::RepositoryNotFound exception if no git
  # directory exists in any of +path+'s parents.
  #
  def self.find_work_path(path)
    path.absolute.ascend do |p|
      return p if p.join(GIT_DIR).exists?
    end
    
    raise Git::RepositoryNotFound, "#{path} is not in a git repository"
  end
end