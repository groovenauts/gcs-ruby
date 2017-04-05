require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rake/extensiontask"

task :build => :compile

Rake::ExtensionTask.new("gcs") do |ext|
  ext.lib_dir = "lib/gcs"
end

task :default => [:clobber, :compile, :spec]
