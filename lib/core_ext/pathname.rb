class Pathname
  def dot?
    to_s == '.'
  end
  
  def dot_dot?
    to_s == '..'
  end
  
  #
  # Returns true if +path+ is a subdirectory of self.
  #
  def subdir_of?(path)
    parent = path.expand_path
    child  = self.expand_path
    
    child.relative_path_from(parent).to_s[0, 2] != '..'
  end
end