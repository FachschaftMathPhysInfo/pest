class Course < Base
  has_many :profs
  has_one :term
  has_one :form
  has_one :faculty
  has_many :course_profs
  has_many :c_pics
  has_many :tutors
  # Same as above, but do not include the default domain. Intended for
# display where “user@“ is sufficient to know what the address is.
  def fs_contact_addresses_short
    fs_contact_addresses.gsub(/#{SCs[:standard_mail_domain]}$/, "")
  end
  # lovely helper function: we want to guess the mail address of
  # evaluators from their name, simply by adding a standand mail
  # domain to it. Returns comma separated list.
  def fs_contact_addresses
    fs_contact_addresses_array.join(',')
  end

  # lovely helper function: we want to guess the mail address of
  # evaluators from their name, simply by adding a standand mail
  # domain to it. Returns array
  def fs_contact_addresses_array
    pre_format = fscontact.blank? ? evaluator : fscontact
    return [] if pre_format.nil?

    pre_format.split(',').map do |a|
      (a =~ /@/ ) ? a : a + '@' + SCs[:standard_mail_domain]
    end
  end

end
