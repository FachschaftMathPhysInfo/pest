namespace :forms do
  desc "Generate forms"
  task :generate, :term_id do |a,t|
    puts "moin"
    puts t
  end
  desc "Create form samples for all available forms. Leave empty for current terms."
  task :samples, :term_id do |t,a|
    forms = if a.term_id.nil?
      Term.where(is_active:true).map { |s| s.forms }.flatten
    else
      Term.find(a.term_id).first.forms
    end

    forms.each do |f|
      f.languages.each do |l|
         make_sample_sheet(f, l)
      end
    end
# TODO: Uncomment after building clean
#    Rake::Task["clean".to_sym].invoke
  end
  desc "(1) Generate the forms for each course and prof. Leave empty for current terms."
  task :generate, [:term_id] do |t, a|
    dirname = './tmp/forms/'
    FileUtils.mkdir_p(dirname)

    cps = if a.term_id.nil?
      Term.where(is_active:true).map { |s| s.course_profs }.flatten
    else
      Term.find(a.term_id).course_profs
    end
    prog = 0
    puts
    puts "Creating forms:"
    missing_students = []
    cps.each do |cp|
      p cp
      #work_queue.enqueue_b do
        if cp.course.students.blank?
          missing_students << cp.course.title
        else
          make_pdf_for(cp, dirname)
        end
        prog += 1
        print_progress(prog, cps.size, cp.course.title)
     # end
    end

    unless missing_students.empty?
      warn "There are courses that don’t have their student count specified."
      warn missing_students.compact.join("\n")
      warn "No sheets were generated for these courses."
    end

    Rake::Task["forms:cover_sheets"].invoke(a.term_id)
    Rake::Task["clean".to_sym].invoke
    puts
    puts
    puts "Done."
    puts "You can print the forms using «rake forms:print»"
    puts "But remember some forms have been omitted due to missing students count." if missing_students.any?
  end

  desc "Generate cover sheets that contain all available information about the lectures. Leave empty for current terms."
  task :cover_sheets, [:term_id] do |t, a|
    require "#{RAILS_ROOT}/tools/lsf_parser_base.rb"
    LSF.set_debug = false

    dirname = './tmp/forms/covers/'
    FileUtils.mkdir_p(dirname)

    puts "\n\n"
    puts "Please note: Although the covers contain the lecturer’s name"
    puts "they are only customized per lecture. If there are multiple"
    puts "lecturers the name of the last lecturer will be used (when"
    puts "sorted by fullname). This allows to print the cover page only"
    puts "once and have it printed on top of the last stack of that"
    puts "lecture."

    courses =  if a.term_id.nil?
      Term.where(is_active:true).map { |s| s.courses }.flatten
    else
      Term.find(a.term_id).courses
    end

    prog = 0

    puts
    puts "Creating cover sheets:"
    courses.each do |c|
        cp = c.course_profs.sort_by { |cp| cp.get_filename }.last
        # probably should have language selector…
        path = "#{dirname}cover #{cp.get_filename}.tex"
        em_url = "#NEEDSFIXING/courses/#{c.id}/emergency_printing"
        tex = ERB.new(RT.load_tex("../form_cover")).result(binding)
        File.open(path, 'w') {|f| f.write(tex) }
        xetex_to_pdf(path, true, true)
        prog += 1
        print_progress(prog, courses.size, c.title)
    end
  end
  desc "(2) Print all #{"existing".bold} forms in tmp/forms. Uses local print by default."
  task :print => "misc:howtos" do
    p Config.application_paths[:print]
    system(Config.application_paths[:print])
  end
end
