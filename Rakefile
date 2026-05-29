require "bundler/setup"

require "bundler/gem_tasks"
require "bundler/audit/task"
require "rubocop/rake_task"
require "rspec/core/rake_task"

Bundler::Audit::Task.new
RuboCop::RakeTask.new
RSpec::Core::RakeTask.new(:spec)

desc "Verify Zeitwerk can eager-load all engine files without errors"
task :zeitwerk do
  sh({ "RAILS_ENV" => "test" }, "cd spec/dummy && bundle exec rails runner 'Rails.autoloaders.main.eager_load'")
end

task default: ["bundle:audit:update", "bundle:audit:check", :rubocop, :zeitwerk, :spec]

# Development database tasks (operate on spec/dummy)
namespace :dev do
  dummy_env = { "RAILS_ENV" => "development" }
  dummy_rake = "cd spec/dummy && bundle exec rake"

  desc "Create and load the development database from schema"
  task :setup do
    sh dummy_env, "#{dummy_rake} db:create db:schema:load"
  end

  desc "Seed the development database"
  task :seed do
    sh dummy_env, "#{dummy_rake} db:seed"
  end

  desc "Drop, recreate, load schema, and seed the development database"
  task :reset do
    sh dummy_env, "#{dummy_rake} db:drop db:create db:schema:load db:seed"
  end
end
