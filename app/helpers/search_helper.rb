# frozen_string_literal: true

module SearchHelper
  def cta_for_offender(prison, offender)
    offender_id = offender.offender_no

    if offender.tier.blank?
      link_to(
        'Edit',
        new_prison_case_information_path(prison, nomis_offender_id: offender_id)
        )
    elsif offender.allocated_pom_name.blank?
      link_to(
        'Allocate',
        new_prison_allocation_path(prison, nomis_offender_id: offender_id)
      )
    else
      link_to(
        'View',
        prison_allocation_path(prison, nomis_offender_id: offender_id)
      )
    end
  end
end
