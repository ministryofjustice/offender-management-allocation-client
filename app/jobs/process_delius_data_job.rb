# frozen_string_literal: true

class ProcessDeliusDataJob < ApplicationJob
  queue_as :default

  # HTTP 404 Not Found: Not much point retrying a missing offender
  discard_on Faraday::ResourceNotFound

  # HTTP 409 Conflict: nDelius API fails like this when trying to read a duplicate offender - so don't retry here either
  discard_on Faraday::ConflictError

  include ApplicationHelper

  def perform(nomis_offender_id)
    ApplicationRecord.transaction do
      logger.info("[DELIUS] Processing delius data for #{nomis_offender_id}")

      DeliusImportError.where(nomis_offender_id: nomis_offender_id).destroy_all

      import_data(OpenStruct.new(OffenderService.get_community_data(nomis_offender_id)))
    end
  end

private

  def import_data(delius_record)
    offender = OffenderService.get_offender(delius_record.noms_no)

    if offender.nil?
      # POM-778 Just not covered by tests
      #:nocov:
      return logger.error("[DELIUS] Failed to retrieve NOMIS record #{delius_record.noms_no}")
      #:nocov:
    end

    process_record(delius_record) if offender.convicted?
  end

  def process_record(delius_record)
    case_information = map_delius_to_case_info(delius_record)

    if case_information.changed?
      if case_information.save
        # Recalculate the offender's handover dates
        RecalculateHandoverDateJob.perform_later(delius_record.noms_no)
      else
        case_information.errors.each do |field, _errors|
          DeliusImportError.create! nomis_offender_id: delius_record.noms_no,
                                    error_type: error_type(field)
        end
      end
    end
  end

  def map_delius_to_case_info(delius_record)
    find_case_info(delius_record).tap do |case_info|
      case_info.assign_attributes(
        manual_entry: false,
        com_name: delius_record.offender_manager,
        crn: delius_record.crn,
        tier: map_tier(delius_record.tier),
        local_delivery_unit: map_ldu(delius_record.ldu_code),
        ldu_code: delius_record.ldu_code,
        team_name: delius_record.team_name,
        case_allocation: delius_record.service_provider,
        probation_service: map_probation_service(delius_record.ldu_code),
        mappa_level: map_mappa_level(delius_record.mappa_levels)
      )
    end
  end

  # map the LDU regardless of enabled switch, but only expose it from offender when enabled
  def map_ldu(ldu_code)
    LocalDeliveryUnit.find_by(code: ldu_code)
  end

  def find_case_info(delius_record)
    prisoner = Offender.find_by!(nomis_offender_id: delius_record.noms_no)
    prisoner.case_information || prisoner.build_case_information
  end

  def map_mappa_level(delius_mappa_levels)
    delius_mappa_levels.empty? ? 0 : delius_mappa_levels.max
  end

  def map_probation_service(ldu_code)
    LocalDeliveryUnit.find_by(code: ldu_code)&.country || 'England'
  end

  def map_tier(tier)
    tier[0] if tier.present?
  end

  def error_type(field)
    {
      tier: DeliusImportError::INVALID_TIER,
      case_allocation: DeliusImportError::INVALID_CASE_ALLOCATION,
      local_delivery_unit: DeliusImportError::MISSING_LDU,
      team: DeliusImportError::MISSING_TEAM
    }.fetch(field)
  end
end
