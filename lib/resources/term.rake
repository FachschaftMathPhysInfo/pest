class Term < Base
  has_many :forms
  has_many :courses
  has_many :course_profs
  has_many :tutors
  has_many :faculties
  def dir_friendly_title
    ActiveSupport::Inflector.transliterate(title.strip).gsub(/[^a-z0-9_-]/i, '_')
  end
end
