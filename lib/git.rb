module Git
  VERSION = '0.0.1'
end

require 'core_ext/pathname'

# exceptions
require 'git/exceptions'

# auxiliary classes
require 'git/author'
require 'git/collection'
require 'git/file'

# main classes
require 'git/repository'
require 'git/store'
require 'git/object'
