class Course < Base
  has_many :profs
  has_one :term
  has_one :form
  has_one :faculty
  has_many :course_profs
  has_many :c_pics
  has_many :tutors
end
