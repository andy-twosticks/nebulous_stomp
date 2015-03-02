require "bundler/gem_tasks"
require "rspec/core/rake_task"
require 'rdoc'

RSpec::Core::RakeTask.new(:spec)

RDoc::Task.new do |rdoc|
  rdoc.main = "md/README.md"
  rdoc.rdoc_files.include("lib/*", "md/*")
  rdoc.options << "-r"
  rdoc.rdoc_dir = "doc"
end

task :default => :spec

