class Git::Repository
  GIT_DIR = '.git' # the location of the git dir in a repo
  
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
    self.store     = Git::Store.
  end
  
  def [](id)
    objects.find(id)
  end
  
  def find(id)
    objects.find(id)
  end
  
  def objects
    Git::Collection.new(Git::Object)
  end
  
  def blobs
    Git::Collection.new(Git::Blob)
  end
  
  def trees
    Git::Collection.new(Git::Tree)
  end
  
  def commits
    Git::Collection.new(Git::Commit)
  end
  
  #
  # Sets the working dir of the repository.
  #
  def work_path=(dir)
    @work_path = self.class.find_work_path(dir.to_path).absolute
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
    work_dir.join(GIT_DIR)
  end
  
  private
  
  #
  # Ascends up +path+ finding the top level of the working directory
  # containing +path+. Raises a Git::RepositoryNotFound exception if no git
  # directory exists in any of +path+'s parents.
  #
  def self.find_work_dir(path)
    path.absolute.ascend do |p|
      return p if p.join(GIT_DIR).exists?
    end
    
    raise Git::RepositoryNotFound, "not a git repository"
  end
end