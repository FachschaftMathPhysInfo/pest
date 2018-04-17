class Tutor < Base
  has_one :course
  has_many :pics
  has_one :form
  has_one :faculty
  has_one :term
end
