require 'rake/clean'
require 'rake/rdoctask'

namespace :doc do
  FILES   = Dir['lib/**/*']

  desc 'Generate HTML documentation'
  Rake::RDocTask.new(:html) do |rdoc|
    rdoc.rdoc_dir    = 'doc'
    rdoc.rdoc_files += FILES
    rdoc.options    += %w{ --line-numbers }
  end
end

task :doc   => %w{ doc:html }
task :clean => %w{ doc:clobber_html }