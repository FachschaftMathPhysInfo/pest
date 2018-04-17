class Term < Base
  has_many :forms
  has_many :courses
  has_many :course_profs
  has_many :tutors
  has_many :faculties
end
