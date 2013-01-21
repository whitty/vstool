require 'rubygems'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rake/testtask'
require 'pp'

task :default => [:test]

Rake::TestTask.new do |t|
  t.test_files = FileList['test/tc_*rb']
  #pp t.methods
end

RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/*_spec.rb'
  t.ruby_opts = ['-w']
  # t.rspec_opts = ['-r', 'offline_only']
end
