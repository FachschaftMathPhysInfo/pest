class CPic < Base
  has_one :course_prof
  has_one :course
  has_one :sheet
  has_one :term
  def picture
    Base64.decode64(self.dt)
  end
  def picture=(value)
    self.dt=Base64.encode64(value)
  end
end
