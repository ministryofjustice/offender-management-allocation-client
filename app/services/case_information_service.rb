# frozen_string_literal: true

class CaseInformationService
  def self.get_case_information(offender_ids)
    CaseInformation.includes(:early_allocations, team: :local_divisional_unit).
      where('nomis_offender_id in (?)', offender_ids).map { |case_info|
      [case_info.nomis_offender_id, case_info]
    }.to_h
  end
end
