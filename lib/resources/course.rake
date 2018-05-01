class Course < Base
  RT = ResultTools.instance
  has_many :profs
  has_one :term
  has_one :form
  has_one :faculty
  has_many :course_profs
  has_many :c_pics
  has_many :tutors
  # Same as above, but do not include the default domain. Intended for
# display where “user@“ is sufficient to know what the address is.
  def fs_contact_addresses_short
    fs_contact_addresses.gsub(/#{SCs[:standard_mail_domain]}$/, "")
  end
  # Returns list of tutors sorted by name (instead of adding-order)
def tutors_sorted
  tutors.sort { |x,y| x.abbr_name.casecmp(y.abbr_name) }
end
  # lovely helper function: we want to guess the mail address of
  # evaluators from their name, simply by adding a standand mail
  # domain to it. Returns comma separated list.
  def fs_contact_addresses
    fs_contact_addresses_array.join(',')
  end

  # lovely helper function: we want to guess the mail address of
  # evaluators from their name, simply by adding a standand mail
  # domain to it. Returns array
  def fs_contact_addresses_array
    pre_format = fscontact.blank? ? evaluator : fscontact
    return [] if pre_format.nil?

    pre_format.split(',').map do |a|
      (a =~ /@/ ) ? a : a + '@' + SCs[:standard_mail_domain]
    end
  end
  def dir_friendly_title
    ActiveSupport::Inflector.transliterate(title.strip).gsub(/[^a-z0-9_-]/i, '_')
  end
  # evaluates this whole course against the associated form. if single
# is set, include headers etc.
def evaluate(single=nil)
  puts "   #{title}" if single.nil?

  # if this course doesn't have any lecturers it cannot have been
  # evaluated, since the sheets are coded with the course_prof id
  # Return early to avoid problems.
  if profs.empty?
    warn "  #{title}: no profs -- skipping"
    return ""
  end

  I18n.locale = language if I18n.tainted? or single


  b = "\n\n\n% #{title}\n"

  if single
    evalname = title.escape_for_tex
    b << ERB.new(RT.load_tex("preamble")).result(binding)
    b << RT.load_tex_definitions
    b << '\maketitle' + "\n\n"
    facultylong = faculty.longname
    term_title = { :short => term.title, :long => term.longtitle }
    b << ERB.new(RT.load_tex("preface")).result(binding)
  end

  b << "\\selectlanguage{#{I18n.t :tex_babel_lang}}\n"
  b << eval_lecture_head

  if returned_sheets < SCs[:minimum_sheets_required]
    b << form.too_few_sheets(returned_sheets)
    if single
      b << RT.sample_sheets_and_footer([form])
    end
    return b
  end

  # walk all questions, one section at a time. May split sections into
  # smaller groups if they belong to a different entity (i.e. repeat_
  # for attribute differs)
  form.abstract_form.sections.each do |section|
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
          b << eval_block(block, s)
        when :lecturer
          # when there are repeat_for = lecturer questions in a
          # section that does not include the lecturer’s name in the
          # title, it is added automaticall in order to make it clear
          # to whom this block of questions refers. If there is only
          # one prof, it is assumed it’s clear who is meant.
          s += " (\\lect)" unless s.include?("\\lect") || course_profs.size == 1
          course_profs.each { |cp| b << cp.eval_block(block, s) }
        when :tutor
          s += " (\\tutor)" unless s.include?("\\tutor") || tutors_sorted.size == 1
          tutors_sorted.each { |t| b << t.eval_block(block, s) }
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
# the head per course. this adds stuff like title, submitted
# questionnaires, what kind of people submitted questionnaires etc
def eval_lecture_head
  b = ""
  b << "\\kurskopf{#{title.escape_for_tex}}"
  b << "{#{profs.map { |p| p.fullname.escape_for_tex }.join(' / ')}}"
  b << "{#{returned_sheets}}"
  b << "{#{id}}"
  b << "{#{t(:by)}}\n\n"
  unless note.nil? || note.strip.empty?
    b << RT.small_header(I18n.t(:note))
    b << note.strip
    b << "\n\n"
  end
  b
end
def eval_block(questions, section)
  b = RT.include_form_variables(self)
  b << RT.small_header(section)
  questions.each do |q|
    b << RT.eval_question(form.db_table, q,
          {:barcode => barcodes},
          {:barcode => faculty.barcodes},
          self)
  end
  b
end
# Returns array of integer-barcodes that belong to this course. It is
# actually an array of the id of the course_prof class.
def barcodes
  course_profs.map { |cp| cp.id }
end
end
