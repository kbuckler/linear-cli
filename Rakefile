require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc 'Run RSpec tests'
task :test do
  Rake::Task[:spec].invoke
end

desc 'Run RuboCop'
task :lint do
  Rake::Task[:rubocop].invoke
end

desc 'Run the full test suite including RSpec tests and RuboCop'
task :full_test do
  Rake::Task[:spec].invoke
  Rake::Task[:rubocop].invoke
end
