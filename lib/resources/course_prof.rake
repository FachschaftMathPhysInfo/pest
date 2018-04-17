class CourseProf < Base
  has_one :course
  has_one :prof
  has_one :form
  has_one :term
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
end
