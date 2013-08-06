require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "yard"
require "yard/rake/yardoc_task"

RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = 'spec/crubyflie_spec.rb'
end

YARD::Rake::YardocTask.new(:yard)

task :doc => :yard
task :test => :spec
task :default => [:spec, :doc]

