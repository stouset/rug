class Pathname
  #
  # Returns true if +path+ is a subdirectory of self.
  #
  def subdir_of?(path)
    parent = path.expand_path
    child  = self.expand_path
    
    parent.relative_path_from(child).to_s[0, 2] == '..'
  end
end