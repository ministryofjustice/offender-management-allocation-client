# frozen_string_literal: true

module PageHelper
  def back_link(class_name = 'govuk-back-link govuk-!-margin-top-0 govuk-!-margin-bottom-6')
    if request.env['HTTP_REFERER'].present? &&
        request.env['HTTP_REFERER'] != request.env['REQUEST_URI']
      link_to('Back', :back, class: class_name)
    else
      # POM-778 Just not covered by tests
      #:nocov:
      link_to('Back', root_path, class: class_name)
      #:nocov:
    end
  end

  def field_error(errors, field)
    if errors.present? && errors[field].present?
      'govuk-form-group govuk-form-group--error'
    else
      'govuk-form-group'
    end
  end
end
