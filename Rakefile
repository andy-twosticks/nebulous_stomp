require "bundler/gem_tasks"
require "rspec/core/rake_task"
require 'rdoc/task'


# Monkey patch Bundler gem_helper so we release to our gem server instead of
# rubygems.org
# http://www.alexrothenberg.com/2011/09/16/running-a-private-gemserver-inside-the-firewall.html
module Bundler
  class GemHelper
    def rubygem_push(path)
      gem_server_url = 'http://centos7andy.jhallpr.com:4242'
      sh("gem inabox '#{path}' --host #{gem_server_url}")
      Bundler.ui.confirm "Pushed #{name} #{version} to #{gem_server_url}"
    end
  end
end


RSpec::Core::RakeTask.new(:spec)

namespace :rdoc do
  RDoc::Task.new do |rdoc|
    rdoc.main = "md/README.md"
    rdoc.rdoc_files.include("lib/*", "md/*")
    rdoc.options << "-r"
    rdoc.rdoc_dir = "doc"
  end

  desc "Generate for ri command"
  task :ri do
    sh "rdoc -R"
  end
end

desc "Start Guard"
task :guard do
  sh "bundle exec guard"
end

desc "Update vim tag data"
task :retag do
  sh "ripper-tags -R"
end
   

