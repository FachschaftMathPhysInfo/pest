# encoding: utf-8

namespace :images do
  desc "(3) Run the scan script to import pages to #{simplify_path(SCfp[:scanned_pages_dir])}"
  task :scan do
    FileUtils.makedirs(SCfp[:scanned_pages_dir])
    Dir.chdir(SCfp[:scanned_pages_dir]) do
      puts SCc[:scan]
      system(SCc[:scan])
    end
    puts
    puts "Next recommended step: rake images:sortandalign"
  end
  desc "Import from "
  task :import_from_dir, :directory do | t, d|
        # use default directory if none given
        if d.directory.nil? || d.directory.empty?
          d = {}
          d[:directory] = SCfp[:scanned_pages_dir]
          FileUtils.makedirs(d[:directory])
        end

        # abort if the directory of choice does not exist for some reason
        abort("Given directory does not exist. Aborting.") unless File.directory?(d[:directory])

        # actually sort the images
        puts "Working directory is: #{simplify_path d[:directory]}"
        files = Dir.glob(File.join(d[:directory], '*.tiff'))
        p files
        sort_path = SCfp[:sorted_pages_dir]

        curr = 0
        errs = []

        puts "Reading course information"
        # Unfortunately ActiveRecord is not always threadsafe, which leads
        # to some threads failing. For this reason and to prevent the n+1
        # queries problem, select all required data in one go.
        data = {}
        # Rails magic tries too hard and loads much more information than
        # required, making the auto-generated query very slow. This one is
        # fast enough.
        Course.includes(:form,:course_profs).map do |c|
          c.course_profs.each do |cp|
            p cp.id
            data[cp.id.to_i]={:lang=>c.language,:form_id=>c.form.id}
          end
        end
        p files
        files.each do |f|
          barcode= File.basename(f).split("-")[0]
          basename= "scanned_"+File.basename(f).split("-")[1].split(".")[0].rjust(6, '0')
          form = "#{data[barcode.to_i][:form_id]}_#{data[barcode.to_i][:lang]}"
          FileUtils.makedirs(File.join(sort_path, form))
          FileUtils.move(f, File.join(sort_path, form, "#{barcode}_#{basename}.tif"))
        end
  end
  desc "(4) Sort scanned images by barcode (#{simplify_path(SCfp[:scanned_pages_dir])} → #{simplify_path(SCfp[:sorted_pages_dir])})"
  task :sortandalign, :directory do |t, d|
    # use default directory if none given
    if d.directory.nil? || d.directory.empty?
      d = {}
      d[:directory] = SCfp[:scanned_pages_dir]
      FileUtils.makedirs(d[:directory])
    end

    # abort if the directory of choice does not exist for some reason
    abort("Given directory does not exist. Aborting.") unless File.directory?(d[:directory])

    # actually sort the images
    puts "Working directory is: #{simplify_path d[:directory]}"
    files = Dir.glob(File.join(d[:directory], '*.tif'))
    sort_path = SCfp[:sorted_pages_dir]

    curr = 0
    errs = []

    puts "Reading course information"
    # Unfortunately ActiveRecord is not always threadsafe, which leads
    # to some threads failing. For this reason and to prevent the n+1
    # queries problem, select all required data in one go.
    data = {}
    # Rails magic tries too hard and loads much more information than
    # required, making the auto-generated query very slow. This one is
    # fast enough.
    Course.includes(:form,:course_profs).map do |c|
      c.course_profs.each do |cp|
        p cp.id
        data[cp.id.to_i]={:lang=>c.language,:form_id=>c.form.id}
      end
    end
    p data

    files.each do |f|
      unless File.writable?(f)
        puts "No write access, cancelling."
        break
      end
        begin
          basename = File.basename(f, '.tif')
          zbar_result = find_barcode(f)
          barcode = (zbar_result.to_f / 10.0).floor.to_i
          p barcode
          p zbar_result
          # retry in case a non-existant barcode was found
          if zbar_result && (not data.include?(barcode))
            zbar_result = find_barcode(f, true)
            barcode = (zbar_result.to_f / 10.0).floor.to_i
          end

          if zbar_result.nil? || (not data.include?(barcode))
            reason = zbar_result ? "CourseProf (#{zbar_result}) does not exist" : "Barcode not found"
            errs << "bizarre #{basename}: #{reason}"
            FileUtils.makedirs(File.join(sort_path, "bizarre"))
            FileUtils.move(f, File.join(sort_path, "bizarre"))
          else
            form = "#{data[barcode][:form_id]}_#{data[barcode][:lang]}"
            FileUtils.makedirs(File.join(sort_path, form))
            FileUtils.move(f, File.join(sort_path, form, "#{barcode}_#{basename}.tif"))
          end

        rescue Exception => e
          errs << e.message
          errs << e.backtrace
        end

        curr += 1
        print_progress(curr, files.size)
    end
    if errs.empty?
      puts
      puts "Done!"
      puts
      puts "Next recommended step: rake images:omr"
    else
      puts
      puts "There have been some errors:"
      errs.each { |e| puts "   #{e}" }
      puts
      puts "Investigate and run again: rake images:sortandalign"
    end
  end

  desc "(5) Evaluates all sheets in #{simplify_path(SCfp[:sorted_pages_dir])}"
  task :omr => 'images:getyamls' do
    # OMR needs the YAML files as TeX also outputs position information
    p = SCfp[:sorted_pages_dir]
    byebug
    skipped = []
    Dir.glob(File.join(p, "[0-9]*.yaml")).each do |f|
      unless Dir.exist?(f[0..-6])
        skipped.push f
        next
      end
      puts "\n\n\nNow processing #{f}"
      bn = File.basename(f, ".yaml")
      system(%(./pest/omr2.rb -d -s "#{f}" -p "#{p}/#{bn}" -c #{number_of_processors}))
    end
    p skipped
    puts
    puts "Next recommended step: rake images:correct"
  end

  desc "Try to find empty sheets."
  task :find_empty_sheets do
    checks = 5
    puts "This simple heuristic checks if there are less than"
    puts "#{checks} checkmarks. If there are, the sheet is presented"
    puts "to you so you can decide to throw it out or not."
    all_sql = []
    tables = []
    Term.where(is_active:true).map { |s| s.forms }.flatten.each do |form|
      next unless RT.table_exists?(form.db_table)
      tables << form.db_table
      sql = "SELECT path FROM #{form.db_table} WHERE #{checks} > (0 "
      form.questions.map do |q|
        next unless ["square", "tutor_table"].include?(q.type)
        if q.single?
          sql << "\n+ IF(#{q.db_column} > 0, 1, 0)"
        else
          q.db_column.each { |col| sql << "\n+ IF(#{col} > 0, 1, 0)" }
          sql << "\n+ IF(#{q.db_column.find_common_start+"noansw"} > 0, 1, 0)" if q.no_answer?
        end
      end
      sql << "\n)"
      all_sql << sql
    end
    paths = RT.custom_query(all_sql.join(" UNION ")).map { |row| row["path"] }
    tmp_path = "#{temp_dir}/is_this_sheet_empty.tif"
    paths.each do |p|
      FileUtils.ln_s(p, tmp_path, :force => true)
      fork { exec "#{SCap[:pdf_viewer]} \"#{tmp_path}\" 2>1 &> /dev/null" }
      puts "\n\n\n"
      puts "Image: #{p}"
      print "Delete sheet from disk and database? [y/N] "
      answ = STDIN.gets.strip.downcase
      next if answ == "n" or answ == ""
      redo if answ != "y"
      # delete sheet
      puts "Deleting in DB…"
      tables.each do |table|
        RT.custom_query_no_result("DELETE FROM #{table} WHERE path = ?", [p])
      end
      puts "From disk…"
      FileUtils.rm(p, :force => true) # try to delete, but don’t report errors
    end
    # cleanup
    FileUtils.rm(tmp_path, :force => true)
    puts "Done. All empty sheets have been removed."
  end

  desc "(6) Correct invalid sheets"
  task :correct do
    forms = Term.where(is_active:true).map { |s| s.forms }.flatten
    tables = forms.collect { |form| form.db_table }
    system("./pest/fix.rb #{tables.join(" ")}")

    puts
    puts "Next recommended step: rake images:fill_text_box"
  end

  desc "(7) Fill in small text boxes (not comments)"
  task :fill_text_box do
    system("./pest/fill_text_box.rb")
    puts
    puts "Next recommended step: rake images:insertcomments"
  end

  desc "(8) make handwritten comments known to the web-UI (i.e. find JPGs in #{simplify_path(SCfp[:sorted_pages_dir])})"
  task :insertcomments do |t, d|
    cp = SCc[:cp_comment_image_directory]
    mkdir = SCc[:mkdir_comment_image_directory]
    tut_num_nil = 0
    tut_num_l0 = 0
    tut_num_null = 0
    tut_num_count_greater = 0
    Term.where(is_active:true).each do |sem|
      path=File.join(File.dirname(__FILE__), "tmp/images")

      # find all existing images for courses/profs and tutors
      bcs = sem.barcodes
      cpics = bcs.map{|bc| CourseProf.find(bc).first.c_pics.map{|cp| cp.basename}}.flatten
      tpics =  sem.courses.map { |c| c.tutors.map { |t| t.pics.map{|p| p.basename} } }.flatten

      # find all tables that include a tutor chooser
      forms = sem.forms.find_all { |form| form.abstract_form.include_question_type?("tutor_table") }
      tables = {}
      forms.each { |form| tables[form.db_table] = form.abstract_form.get_tutor_question.db_column }

      allfiles = Dir.glob(File.join(SCfp[:sorted_pages_dir], '**/*.jpg'))
      allfiles.each_with_index do |f, curr|
        bname = File.basename(f)
        next if bname =~ /_DEBUG/
        source = f.sub(/_[^_]+$/, "") + ".tif"
        p (curr.to_f/allfiles.count.to_f)*100
        p source
        # upload sheet
        sheet= Sheet.find(uid:source).first
        p sheet if sheet.nil?
        begin
        sheet= Sheet.create(uid:source, picture:File.read(source)) if sheet.nil?
        rescue => error
          p error
          byebug
        end
        barcode = find_barcode_from_path(f)

        if barcode == 0
          warn "\nCouldn’t detect barcode for #{bname}, skipping.\n"
          next
        end

        course_prof = CourseProf.find(barcode) rescue nil
        if course_prof.nil?
          warn "\nCouldn’t find Course/Prof for barcode #{barcode} (image: #{bname}). Skipping.\n"
          next
        end

        p = nil
        # tutor comments, place them under each tutor
        if f.downcase.end_with?("_ucomment.jpg")
          # skip existing images
          next if tpics.include?(bname)
          # find tutor id
          tut_num = nil
          tables.each do |table, column|
            next unless CourseProf.find(bname.split("_")[0]).first.course.form.db_table ==table
            data = Result.find(table).first.find_tutor(column:column, path:source).first.res
            tut_num = data[column].to_i if data
            break if tut_num
          end
          # load tutors
          tutors = course_prof.first.course.tutors.sort { |a,b| a.id <=> b.id }
          if tut_num.nil?
            tut_num_nil = tut_num_nil+1
            def_tut = tutors.find{|t| t.abbr_name == "Unassigned"}
            if def_tut.nil?
              def_tut = Tutor.new(abbr_name:"Unassigned")
              def_tut.relationships.course = course_prof.first.course
              def_tut.save
              tutors.push(def_tut)
            end
            tut_num = tutors.find_index(def_tut) +1
            warn "\n\nCouldn’t find any record in the results database for #{bname}. Cannot match tutor image. Skipping.\n"
            #next
          end

          if tut_num == 0
            tut_num_null = tut_num_null+1
            def_tut = tutors.find{|t| t.abbr_name == "Unassigned"}
            if def_tut.nil?
              def_tut = Tutor.new(abbr_name:"Unassigned")
              def_tut.relationships.course = course_prof.first.course
              def_tut.save
              tutors.push(def_tut)
            end
            tut_num = tutors.find_index(def_tut) +1
            warn "\n\nCouldn’t add tutor image #{bname}, because no tutor was chosen (or marked invalid). Skipping.\n"
            #next
          end



          if tut_num < 0
            tut_num_l0 = tut_num_l0+1
            def_tut = tutors.find{|t| t.abbr_name == "Unassigned"}
            if def_tut.nil?
              def_tut = Tutor.new(abbr_name:"Unassigned")
              def_tut.relationships.course = course_prof.first.course
              def_tut.save
              tutors.push(def_tut)
            end
            tut_num = tutors.find_index(def_tut) +1
            warn "\n\nCouldn’t add tutor image #{bname}, because OMR result is ambigious. Have you run `rake images:correct`?"
            #next
          end


          if tut_num > tutors.count
            tut_num_count_greater = tut_num_count_greater+1
            def_tut = tutors.find{|t| t.abbr_name == "Unassigned"}
            if def_tut.nil?
              def_tut = Tutor.new(abbr_name:"Unassigned")
              def_tut.relationships.course = course_prof.first.course
              def_tut.save
              tutors.push(def_tut)
            end
            tut_num = tutors.find_index(def_tut) +1
            warn "\n\nCouldn’t add tutor image #{bname}, because chosen tutor does not exist (checked field num > tutors.count). Skipping.\n"
            #next
          end

          p = Pic.new
          p tutors[tut_num-1]
          p.relationships.tutor = tutors[tut_num-1]
        else # files for the course/prof. Should be split up. FIXME.
          next if cpics.include?(bname)
          p = CPic.new
          p.relationships.course_prof = course_prof.first
        end
        p.relationships.sheet = sheet
        p.basename = bname
        p.source = source
        p.picture = File.read(f)
                # let rails know about this comment
        p.save
        print_progress(curr+1, allfiles.size)
      end # Dir glob
    end # Term.each
    puts tut_num_nil
    puts tut_num_l0
    puts tut_num_null
    puts tut_num_count_greater
    puts
    puts "Done."
    puts
    puts "Next recommended step: Type all comments in the web interface."
    puts "After that, the commands in the “rake results:*” group should help you."
  end

  # find forms for current term and extract variables from the
  # first key that comes along. The language should exist for every
  # key, even though this is currently not enforced. Will be though,
  # once a graphical form creation interface exists.
  # Note: should be deprecated by forms:generate once we switch to
  # per CourseProf evaluation
  desc "Finds all different forms for each folder and saves the form file as #{simplify_path(SCfp[:sorted_pages_dir])}/[form id].yaml."
  task :getyamls do |t,o|
    `mkdir -p ./tmp/images`
    forms = Term.where(is_active:true).map { |s| s.forms }.flatten
    forms.each do |form|
      if form.abstract_form.lecturer_header.is_a? String then
        lang ="de"
        target = File.join(SCfp[:sorted_pages_dir], "#{form.id}_#{lang}.yaml")
        next if File.exists?(target)
        file = make_sample_sheet(form, lang)
        FileUtils.move("#{file}.yaml", target)
      else
        form.abstract_form.lecturer_header.keys.collect do |lang|
          target = File.join(SCfp[:sorted_pages_dir], "#{form.id}_#{lang}.yaml")
          next if File.exists?(target)
          file = make_sample_sheet(form, lang)
          FileUtils.move("#{file}.yaml", target)
        end
      end
    end
  end



end
