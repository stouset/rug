module Git
  GIT_DIR = '.git'
  
  #
  # Returns a path relative to the current git directory. Joins all parts to
  # create the path. If given no parameters, returns the path to the git dir
  # itself.
  #--
  # TODO: Move into the configuration system, when we have one
  #++
  #
  def self.path(*parts)
    File.join(GIT_DIR, *parts)
  end
end

require 'git/exceptions'
require 'git/store'
require 'git/object'