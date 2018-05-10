require File.join(File.dirname(__FILE__),"../FunkyTeXBits.rb")
class Term < Base
  RT = ResultTools.instance
  include FunkyTeXBits
  has_many :forms
  has_many :courses
  has_many :course_profs
  has_many :tutors
  has_many :faculties
  def dir_friendly_title
    ActiveSupport::Inflector.transliterate(title.strip).gsub(/[^a-z0-9_-]/i, '_')
  end
  # evaluate a faculty
  def evaluate(faculty)
    tables = forms.map { |f| f.db_table }

    # Let the database do the selection and sorting work. Also include
    # tutor and prof models since we are going to count them later on.
    # Since we need all barcodes, include course_prof as well.
    cs = Course.where(faculty_id:faculty.id,term_id:self.id).order(title: :asc).includes(:course_profs, :profs, :tutors)

    course_count = cs.count
    sheet_count = RT.count(tables, {:barcode => faculty.barcodes })
    prof_count = cs.map { |c| c.profs }.flatten.uniq.count
    study_group_count = cs.inject(0) { |sum, c| sum + c.tutors.count }

    evalname = faculty.longname + ' ' + title

    b = ""
    # requires evalname
    b << ERB.new(RT.load_tex("preamble")).result(binding)
    b << RT.load_tex_definitions
    # requires the *_count variables
    b << ERB.new(RT.load_tex("header")).result(binding)

    facultylong = faculty.longname
    term_title = { :short => title, :long => longtitle }
    b << ERB.new(RT.load_tex("preface")).result(binding)

    puts "Evaluating #{cs.count} courses…"
    cs.each { |c| b << c.evaluate.to_s }

    b << RT.sample_sheets_and_footer(forms)
    return b
  end
end
