require 'json_api_client'
require 'yaml'
require "byebug"
Rake.add_rakelib 'lib'
Rake.add_rakelib 'lib/resources'
Rake.add_rakelib 'rakefiles'
Rake.add_rakelib 'config'
require 'rake/clean'
CLEAN.include('tmp/**/*.log', 'tmp/**/*.out', 'tmp/**/*.aux',
  'tmp/**/*.toc', 'tmp/blame.tex', 'tmp/forms/**/*.tex')
#require './app/resources/base.rb'
#require './app/resources/form.rb'
# automatically calls rake -T when no task is given
# Creates a sample sheet in tmp/sample_sheets for the given form (object)
# and language name. Returns the full filepath, but without the file
# extension. Does not re-create existing files.
def make_sample_sheet(form, lang)
  # this is hardcoded throughout the project
  dir = "tmp/sample_sheets/"
  FileUtils.makedirs(dir)
  filename = "#{dir}sample_#{form.id}#{lang.to_s.empty? ? "" : "_#{lang}"}"

  form_misses_files = !File.exist?(filename+'.pdf') || !File.exist?(filename+'.yaml')
  # see if the form is newer than any of the files
  form_needs_regen = form_misses_files \
                      || form.updated_at > File.mtime(filename+'.pdf') \
                      || form.updated_at > File.mtime(filename+'.yaml')

  # PDFs are required for result generation and the posouts for OMR
  # parsing. Only skip if both files are present and newer than the
  # form itself.
  if !form_needs_regen && File.exists?(filename+'.pdf') && File.exists?(filename+'.yaml')
    return filename
  end

  File.open(filename + ".tex", "w") do |h|
    h << form.abstract_form.to_tex(lang, form.db_table)
  end

  puts "Wrote #{filename}.tex"
  tex_to_pdf("#{filename}.tex", true)
  lines_posout = %x{wc -l #{filename}.posout}.split.first.to_i
  `./pest/latexfix.rb "#{filename}.posout" && rm "#{filename}.posout"`
  lines_yaml = %x{wc -l #{filename}.yaml}.split.first.to_i
  raise "Converting error: # lines of posout and yaml differ." if lines_yaml != lines_posout
  filename
end
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
