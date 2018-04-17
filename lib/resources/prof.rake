class Prof < Base
  has_many :course_profs
  has_many :courses
end
