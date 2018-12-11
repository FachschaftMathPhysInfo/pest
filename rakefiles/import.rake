namespace :import do
  
  desc "Iterate through list"
  task :enter_location_and_time,[:term] do |t,a|
    ARGV.clear
    term = Term.find(a.term).first
    term.courses.each do |course|
      puts course.title
      puts "Ort:"
      ort = gets
      puts "Zeit:"
      zeit = gets
      course.description = "#{ort} (#{zeit})"
      course.save
    end
  end
end
