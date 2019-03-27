class OffenderService
  # rubocop:disable Metrics/MethodLength
  def self.get_offender(offender_no)
    Nomis::Elite2::OffenderApi.get_offender(offender_no).tap { |o|
      record = CaseInformation.find_by(nomis_offender_id: offender_no)

      if record.present?
        o.tier = record.tier
        o.case_allocation = record.case_allocation
        o.omicable = record.omicable
      end

      sentence_detail = get_sentence_details([o.latest_booking_id])
      if sentence_detail.present? && sentence_detail.key?(offender_no)
        o.sentence_detail = sentence_detail[offender_no]
      end

      o.main_offence = Nomis::Elite2::OffenderApi.get_offence(o.latest_booking_id)
    }
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/PerceivedComplexity
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/LineLength
  def self.get_offenders_for_prison(prison, page_number: 0, page_size: 10, tier_map: nil)
    offenders = Nomis::Elite2::OffenderApi.list(
      prison,
      page_number,
      page_size: page_size
    ).data

    booking_ids = offenders.map(&:booking_id)

    mapped_tiers = tier_map || CaseInformationService.get_case_information(prison)

    sentence_details = if booking_ids.count > 0
                         sentence_details = Nomis::Elite2::OffenderApi.get_bulk_sentence_details(
                           booking_ids
                         )
                       else
                         {}
                       end

    offenders.select { |offender|
      next false unless offender.convicted_status == 'Convicted'

      sentencing = sentence_details[offender.offender_no]
      offender.sentence_detail = sentencing if sentencing.present?
      next false unless offender.sentenced?

      record = mapped_tiers[offender.offender_no]
      if record
        offender.tier = record.tier
        offender.case_allocation = record.case_allocation
        offender.omicable = record.omicable
      end

      true
    }
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/LineLength
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/CyclomaticComplexity

  def self.get_sentence_details(booking_ids)
    Nomis::Elite2::OffenderApi.get_bulk_sentence_details(booking_ids)
  end

  def self.allocations_for_offenders(offender_id_list)
    Allocation.where(
      nomis_offender_id: offender_id_list, active: true
    ).preload(:pom_detail)
  end

  # Takes a list of OffenderShort or Offender objects, and returns them with their
  # allocated POM name set in :allocated_pom_name
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/LineLength
  def self.set_allocated_pom_name(offenders, caseload)
    pom_names = PrisonOffenderManagerService.get_pom_names(caseload)
    offender_ids = offenders.map(&:offender_no)
    offender_to_staff_hash = allocations_for_offenders(offender_ids).map { |a|
      [
        a.nomis_offender_id,
        {
          pom_name: pom_names[a.pom_detail.nomis_staff_id],
          allocation_date: a.created_at
        }
      ]
    }.to_h

    offenders.map do |offender|
      if offender_to_staff_hash.key?(offender.offender_no)
        offender.allocated_pom_name = offender_to_staff_hash[offender.offender_no][:pom_name]
        offender.allocation_date = offender_to_staff_hash[offender.offender_no][:allocation_date]
      end
      offender
    end
  end
  # rubocop:enable Metrics/LineLength
  # rubocop:enable Metrics/MethodLength
end
