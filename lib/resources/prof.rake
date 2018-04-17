class Prof < Base
  has_many :course_profs
  has_many :courses
  def fullname
    "#{firstname} #{surname}"
  end

  def surnamefirst
    "#{surname}, #{firstname}"
  end
  def lastname
    surname
  end
end
