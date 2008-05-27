require 'rake/clean'
require 'rake/rdoctask'

namespace :doc do
  desc 'Generate HTML documentation'
  Rake::RDocTask.new(:html) do |rdoc|
    rdoc.rdoc_dir    = 'doc'
    rdoc.options    += %w{ --line-numbers --inline-source }
  end
end

task :doc   => %w{ doc:html }
task :clean => %w{ doc:clobber_html }