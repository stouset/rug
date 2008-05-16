require 'pathname'

class Git::Repository
  GIT_DIR_NAME    = '.git'   # the location of the git dir in a repo
  OBJECT_DIR_NAME = 'object' # the location of the object dir in git
  
  #
  # Joins all +parts+ to create a path relative to the current working
  # directory. If no +parts+ are passed, simply returns the path to the
  # working directory.
  #
  def self.work_path(*parts)
    work_dir.join(*parts)
  end
  
  #
  # Joins all +parts+ to create a path relative to the current git directory.
  # If no +parts+ are passed, simply returns the path to the git directory.
  #
  def self.git_path(*parts)
    git_dir.join(*parts)
  end
  
  #
  # Joins all +parts+ to create a path relative to the current object store
  # directory. If no +parts+ are passed, simply returns the path to the object
  # store directory.
  #
  def self.object_path(*parts)
    git_dir.join(OBJECT_DIR_NAME, *parts)
  end
  
  private
  
  #
  # Returns the full path to the current working directory. Caches the result,
  # so the working dir will never end up changing on us mid-execution.
  #
  def self.work_dir
    @work_dir ||= self.git_dir.parent
  end
  
  #
  # Returns the full path to the current git directory. Caches the result, so
  # the git dir will never end up changing on us mid-execution.
  #
  def self.git_dir
    @git_dir ||= find_git_dir(Pathname.getwd)
  end
  
  #
  # Ascends up +path+ finding the git directory responsible for the location
  # passed. Raises a Git::RepositoryNotFound exception if no git directory
  # exists in any of +path+'s parents.
  #
  def find_git_dir(path)
    path.expand_path.ascend do |p|
      return p if p.join(GIT_DIR_NAME).exist?
    end
    
    raise Git::RepositoryNotFound, path
  end
end