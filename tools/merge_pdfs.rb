#!/usr/bin/env ruby
# Usage: multiply_pdfs.rb path/to/some/pdfs
# The PDFs must end in "1234pcs.pdf" where
# the number defines how many copies should
# be included in the new PDF file.
require 'open3'
require 'byebug'
err = []

Dir.chdir(ARGV[0]) if ARGV[0]

files = Dir.glob('*[0-9]pcs.pdf')

i = 0
files.each do |x|
  i += 1
  match = x.match(/^(.*?)([0-9]+)pcs.pdf$/)
  num = match[2].to_i
  nam = match[1]

  # p nam
  # p num
  cf = "covers/cover #{nam + num.to_s}pcs.pdf"

  if File.exist?("covers/cover #{nam + num.to_s}pcs.pdf")
    next if File.exist?(" covered #{x}")
    puts 'covering'
    # Will likely break for non-latin1 characters, although
    # it should be fixed. Ignore that for the moment.
    stdout, stderr, status = Open3.capture3("pdftk A=\"#{x}\" B=\"#{cf}\" C=\"#{ARGV[1]}\" cat C C  B C A output \" covered #{x}\"")
    p stderr
    p stdout
  else
    puts x
        end
end
puts 'ENDE'
cf_files = Dir.glob(' covered*.pdf')
cf_files.each do |cf|
  puts cf.to_s
end
p cf_files
puts 'Covered are beeing merged'
Open3.capture3('pdftk *covered* cat output zusammen.pdf')
puts "Done (processed #{files.count} file(s) with #{err.count} error(s))"
puts
puts 'The following documents could no be processed:' unless err.empty?
puts err.join("\n")
puts i
