class Resultpage < Base
  def form
    Marshal.load(Base64.decode64(self.abstract_form))
  end
end
