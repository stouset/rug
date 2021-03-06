#
# Attempt to load pathname3 by default. If it doesn't exist, use pathname
# instead.
#--
# TODO: get working with original pathname
# TODO: avoid rubygems load if possible
#

require 'rubygems'
require 'pathname3'

class Pathname
  #
  # Returns true if +path+ is a subdirectory of self.
  #
  def subdir_of?(path)
    parent = path.expand_path
    child  = self.expand_path
    
    child.relative_path_from(parent).to_s[0, 2] != '..'
  end
end