require 'pathname'

class Git::Repository
  GIT_DIR  = Pathname.new('.git')
  
  WORK_DIR   = GIT_DIR.parent
  OBJECT_DIR = GIT_DIR.join('objects')
  
  #
  # Returns a path relative to the current git directory. Joins all parts to
  # create the path. If given no parameters, returns the path to the git dir
  # itself.
  #
  def self.git_path(*parts)
    GIT_DIR.join(*parts)
  end
  
  def self.object_path(*parts)
    OBJECT_DIR.join(*parts)
  end
  
  def self.work_dir(*parts)
    WORK_DIR.join(*parts)
  end
end