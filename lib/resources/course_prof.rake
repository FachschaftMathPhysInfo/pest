class CourseProf < Base
  RT = ResultTools.instance
  has_one :course
  has_one :prof
  has_one :form
  has_one :term
  has_one :faculty
  has_many :c_pics
  def get_filename
    x = [course.form.name, course.language, course.title,   prof.fullname, \
    course.students.to_s + 'pcs'].join(' - ').gsub(/\s+/,' ')
    x = ActiveSupport::Inflector.transliterate(x)
    x.gsub(/[^a-z0-9_.,:\s\-()]/i, "_")
  end
  def barcode
    return "%07d" % id
  end
  # evaluates the given questions in the scope of this course and prof.
  def eval_block(questions, section)
    b = RT.include_form_variables(self)
    b << RT.small_header(section)
    if returned_sheets < SCs[:minimum_sheets_required]
      b << form.too_few_sheets(returned_sheets)
      # a little magic to see if the header was personalized. If not,
      # add the lecturer’s name here:
      b << " (#{prof.fullname})" unless section.match(/\\lect/)
      return b
    end

    questions.each do |q|
      b << RT.eval_question(form.db_table, q,
            {:barcode => id},
            {:barcode => faculty.barcodes},
            self)
    end
    b
  end
end
