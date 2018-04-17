require 'json_api_client'
require "byebug"
Rake.add_rakelib 'lib/resources'
#require './app/resources/base.rb'
#require './app/resources/form.rb'
# automatically calls rake -T when no task is given

task :default do
  puts "Choose your destiny:"
  Rake::application.options.show_tasks = :tasks
  Rake::application.options.show_task_pattern = //
  Rake::application.display_tasks_and_comments
end
desc "Tests the connection to the server"
task :connect do
  puts ENV["PEST_SERVER"]
  p Form.all
  byebug
end
namespace :forms do
  desc "Generate forms"
  task :generate do
  end
end
