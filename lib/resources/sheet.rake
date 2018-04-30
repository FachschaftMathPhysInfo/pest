class Sheet < Base
  has_many :c_pics
  has_many :pics
  def picture
    Base64.decode64(self.data)
  end
  def picture=(value)
    self.data=Base64.encode64(value)
  end
end
