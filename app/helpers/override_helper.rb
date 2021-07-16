# frozen_string_literal: true

module OverrideHelper
  def display_override_pom(allocation)
    if allocation.recommended_pom_type &&
      allocation.recommended_pom_type == 'prison'
      'Probation POM allocated instead of recommended Prison POM'
    elsif allocation.recommended_pom_type &&
      allocation.recommended_pom_type == 'probation'
      # POM-778 Just not covered by tests
      #:nocov:
      'Prison POM allocated instead of recommended Probation POM'
      #:nocov:
    else
      'Prisoner not allocated to recommended POM'
    end
  end

  def display_override_details(reason, allocation)
    case reason
    when 'no_staff'
      no_staff_detail(allocation)
    when 'suitability'
      suitability_detail(allocation)
    when 'continuity'
      tag.p(' - This POM has worked with the prisoner before',
            class: 'govuk-body govuk-!-margin-bottom-1')
    when 'other'
      tag.p(' - Other reason', class: 'govuk-body govuk-!-margin-bottom-1') +
      tag.p(allocation.override_detail)
    end
  end

private

  def no_staff_detail(allocation)
    if allocation.recommended_pom_type.present?
      tag.p(" - No available #{allocation.recommended_pom_type} POMs",
            class: 'govuk-body govuk-!-margin-bottom-1')
    else
      tag.p(' - No available recommended POMs',
            class: 'govuk-body govuk-!-margin-bottom-1')
    end
  end

  def suitability_detail(allocation)
    if allocation.recommended_pom_type.present?
      tag.p(" - Prisoner assessed as suitable for a #{allocation.recommended_pom_type}
        POM despite tiering calculation", class: 'govuk-body govuk-!-margin-bottom-1') +
      tag.p(allocation.suitability_detail, class: 'govuk-body govuk-!-margin-bottom-1')
    else
      # POM-778 Just not covered by tests
      #:nocov:
      tag.p(' - Prisoner assessed as suitable for recommended POM despite tiering
        calculation', class: 'govuk-body govuk-!-margin-bottom-1')
      tag.p(allocation.suitability_detail, class: 'govuk-body govuk-!-margin-bottom-1')
      #:nocov:
    end
  end
end
