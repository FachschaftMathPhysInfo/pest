class Tutor < Base
  RT = ResultTools.instance
  has_one :course
  has_many :pics
  has_one :form
  has_one :faculty
  has_one :term

  # will count the returned sheets if all necessary data is available.
  # In case of an error, -1 will be returned.
  def returned_sheets
    return 0 if course.profs.empty? || form.abstract_form.get_tutor_question.nil?
    tutor_db_column = form.abstract_form.get_tutor_question.db_column.to_sym
    RT.count(form.db_table, {:barcode => course.barcodes, \
      tutor_db_column => tutnum})
  end
  def eval_block(questions, section)
    b = RT.include_form_variables(self)
    # may be used to reference a specific tutor. For example, the tutor_
    # overview visualizer does this.
    b << RT.small_header(section)
    b << "\\label{tutor#{self.id}}\n"
    if returned_sheets < SCs[:minimum_sheets_required]
      b << form.too_few_sheets(returned_sheets)
      return b
    end
    
    tut_db_col = form.get_tutor_question.db_column.to_sym
    
    questions.each do |q|
      b << RT.eval_question(form.db_table, q,
            # this tutor only
            {:barcode => course.barcodes, tut_db_col => tutnum},
            # all tutors available
            {:barcode => faculty.barcodes},
            self)
    end
    b
  end
  def tutnum
    course.tutors.sort {|x,y| x.id <=> y.id }.find_index{|i| self.id==i.id} + 1
  end
    # evaluates this whole course against the associated form. if single
# is set, include headers etc.
def evaluate(single=nil)
  puts "   #{course.title}" if single.nil?

  # if this course doesn't have any lecturers it cannot have been
  # evaluated, since the sheets are coded with the course_prof id
  # Return early to avoid problems.
  if course.profs.empty?
    warn "  #{title}: no profs -- skipping"
    return ""
  end

  I18n.locale = course.language if I18n.tainted? or single


  b = "\n\n\n% #{course.title}\n"

  if single
    evalname = course.title.escape_for_tex
    b << ERB.new(RT.load_tex("preamble")).result(binding)
    b << RT.load_tex_definitions
    b << '\maketitle' + "\n\n"
    facultylong = course.faculty.longname
    term_title = { :short => course.term.title, :long => course.term.longtitle }
    b << ERB.new(RT.load_tex("preface")).result(binding)
  end

  b << "\\selectlanguage{#{I18n.t :tex_babel_lang}}\n"
  b << course.eval_lecture_head

  if returned_sheets < SCs[:minimum_sheets_required]
    b << course.form.too_few_sheets(returned_sheets)
    if single
      b << RT.sample_sheets_and_footer([form])
    end
    return b
  end

  # walk all questions, one section at a time. May split sections into
  # smaller groups if they belong to a different entity (i.e. repeat_
  # for attribute differs)
  course.form.abstract_form.sections.each do |section|
    questions = Array.new(section.questions)
    # walk all questions in this section
    while !questions.empty?
      # find all questions in this sections until repeat_for changes
      repeat_for = questions.first.repeat_for
      block = []
      while !questions.empty? && questions.first.repeat_for == repeat_for
        block << questions.shift
      end
      # now evaluate that block of questions according to it’s
      # repeat_for/belong_to value
      s = section.any_title
      case repeat_for
        when :course
          puts "Evaluating tutor, skipping course"
        when :lecturer
          # when there are repeat_for = lecturer questions in a
          # section that does not include the lecturer’s name in the
          # title, it is added automaticall in order to make it clear
          # to whom this block of questions refers. If there is only
          # one prof, it is assumed it’s clear who is meant.
          puts "Evaluating tutor, skipping lecturer"
        when :tutor
          s += " (\\tutor)" unless s.include?("\\tutor") || tutors_sorted.size == 1
          b << eval_block(block, s)
        else
          raise "Unimplemented repeat_for type #{repeat_for}"
      end
    end
  end

  if single
    b << RT.sample_sheets_and_footer([form])
  end

  return b
end
def t(string)
  I18n.t(string)
end
end
