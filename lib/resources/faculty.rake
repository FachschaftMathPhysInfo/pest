class Faculty < Base
  has_many :courses
  has_many :course_profs
end
