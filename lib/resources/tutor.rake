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
    course.tutors.find_index{|i| self.id=i.id} + 1
  end
end
