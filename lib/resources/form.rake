class Form < Base
    has_one :term

  # the AbstractForm object belonging to this form
  # this is NOT relational, we just dump the AbstractForm into the database as a YAML-string
  # expiring will be handled in the forms_controller#expire_cache
  def abstract_form
    # cache yaml files for speeeed
    $loaded_yaml_sheets ||= {}
    begin
      $loaded_yaml_sheets[id.to_i] ||= YAML::load(content)
    rescue Exception => e
      # Sheet does not appear to be a valid YAML. In this case the
      # value will be nil (and thus not an AbstractForm). This will
      # later be picked up as an invalid form.
      $loaded_yaml_sheets[id.to_i] = e.message + "\n\n\n" + e.backtrace.join("\n")
      warn "Given AbstractForm is invalid:"
      warn $loaded_yaml_sheets[id.to_i]

      warn content
      #~ logger.warn "\n\n\nGiven content was:\n#{content}"
    end
    $loaded_yaml_sheets[id.to_i]
  end
  def db_table
    name = ("evaldata_" + term.title + "_" + self.name).strip
    name = ActiveSupport::Inflector.transliterate(name).downcase
    name.gsub(/[^a-z0-9_]+/, "_")
  end
  # returns a translated string about too few sheets being available to
  # evaluate (anonymity protection). Supports special strings for 0, 1
  # and more than 1 situations.
  def too_few_sheets(count)
    case count
      when 0 then I18n.t(:too_few_questionnaires)[:null]
      when 1 then I18n.t(:too_few_questionnaires)[:singular]
      else        I18n.t(:too_few_questionnaires)[:plural].gsub(/#1/, count.to_s)
    end
  end
  def abstract_form_valid?
    true# hot fix
  end
    # catches all methods that are not implemented and sees if
  # AbstractForm has them. If it doesn’t either, a more detailed error
  # message is thrown.
  def method_missing(name, *args, &block)
    begin; super; rescue Exception => e
      # Can’t use responds_to? because we need to know about instance
      # methods and not class ones.
      unless AbstractForm.instance_methods.include?(name.to_sym)
        raise "undefined method #{name} for both web/app/models/form.rb and lib/AbstractForm.rb"
      end
      return abstract_form.method(name).call(*args) if abstract_form_valid?
      logger.warn "AbstractForm invalid, therefore can’t call «#{name}»"
      # return nil when AbstractForm has the method, but it cannot be
      # used because the form is invalid
      return nil
    end
  end
end
