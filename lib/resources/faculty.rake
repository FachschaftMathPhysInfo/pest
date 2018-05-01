class Faculty < Base
  has_many :courses
  has_many :course_profs
  # Returns array of integer-barcodes that belong to this course. It is
# actually an array of the id of the course_prof class.
def barcodes
  course_profs.map { |cp| cp.id }
end
end
