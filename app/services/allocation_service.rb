# frozen_string_literal: true

class AllocationService
  def self.allocate_secondary(
    nomis_offender_id:,
    secondary_pom_nomis_id:,
    pom_detail:,
    created_by_username:,
    message:
  )
    alloc_version = Allocation.find_by!(
      nomis_offender_id: nomis_offender_id
    )

    primary_pom = HmppsApi::PrisonApi::PrisonOffenderManagerApi.staff_detail(alloc_version.primary_pom_nomis_id)
    coworking_pom = HmppsApi::PrisonApi::PrisonOffenderManagerApi.staff_detail(secondary_pom_nomis_id)

    created_by_user = HmppsApi::PrisonApi::UserApi.user_details(created_by_username)

    alloc_version.update!(
      secondary_pom_name: "#{coworking_pom.last_name}, #{coworking_pom.first_name}",
      created_by_name: "#{created_by_user.first_name} #{created_by_user.last_name}",
      secondary_pom_nomis_id: secondary_pom_nomis_id,
      event: Allocation::ALLOCATE_SECONDARY_POM,
      event_trigger: Allocation::USER
    )

    # Forward-populate the new allocations table
    self.allocate(
      case_info: CaseInformation.find_by(nomis_offender_id: nomis_offender_id),
      pom_detail: pom_detail,
      allocation_type: :coworking, # this method is only used for coworking allocations
      triggered_by_nomis_username: created_by_username,
      metadata: {
        pom_staff_id: coworking_pom.staff_id,
        pom_first_name: coworking_pom.first_name,
        pom_last_name: coworking_pom.last_name,
        homd_first_name: created_by_user.first_name,
        homd_last_name: created_by_user.last_name
      }
    )

    EmailService.instance(allocation: alloc_version, message: message,
                          pom_nomis_id: alloc_version.primary_pom_nomis_id).
      send_coworking_primary_email(primary_pom.first_name, alloc_version.secondary_pom_name)

    EmailService.instance(allocation: alloc_version, message: message,
                          pom_nomis_id: secondary_pom_nomis_id).
      send_secondary_email(coworking_pom.first_name)
  end

  def self.allocate(case_info:, pom_detail:, allocation_type:, triggered_by_nomis_username:, metadata: {})
    # Destroy existing allocation (if one exists)
    deallocated = case_info.new_allocations.where(allocation_type: allocation_type).destroy_all

    # Create the new allocation
    allocation = case_info.new_allocations.create!(allocation_type: allocation_type, pom_detail: pom_detail)

    # Add metadata to the OffenderEvent
    metadata[:new_allocation_id] = allocation.id
    metadata[:allocation_type] = allocation_type

    # Work out the event type for this allocation (or should we have only one event type?)
    event = if allocation_type == :primary
              deallocated.any? ? :reallocate_primary_pom : :allocate_primary_pom
            else
              deallocated.any? ? :reallocate_coworking_pom : :allocate_coworking_pom
            end

    # Record into the offender event log
    OffenderEvent.create!(nomis_offender_id: case_info.nomis_offender_id,
                          event: event,
                          happened_at: Time.zone.now,
                          triggered_by: :user,
                          triggered_by_nomis_username: triggered_by_nomis_username,
                          metadata: metadata)
  end

  def self.deallocate(case_info:, allocation_type:)
    # Destroy existing allocation (if one exists)
    case_info.new_allocations.where(allocation_type: allocation_type).destroy_all
  end

  def self.create_or_update(params)
    primary_pom = HmppsApi::PrisonApi::PrisonOffenderManagerApi.staff_detail(params[:primary_pom_nomis_id])
    created_by_user = HmppsApi::PrisonApi::UserApi.user_details(params[:created_by_username])

    params_copy = params.except(:created_by_username).merge(
      primary_pom_name: "#{primary_pom.last_name}, #{primary_pom.first_name}",
      created_by_name: "#{created_by_user.first_name} #{created_by_user.last_name}",
      primary_pom_allocated_at: DateTime.now.utc
    )

    # When we look up the current allocation, we only do this for the current
    # offender, and NOT for the current prison. The offender may have been
    # transferred here and their allocation record may have a nil prison.
    alloc_version = Allocation.find_by(
      nomis_offender_id: params_copy[:nomis_offender_id]
    )

    if alloc_version.nil?
      if Allocation.where(prison: params_copy[:prison]).empty?
        PomMailer.new_prison_allocation_email(params_copy[:prison]).deliver_later
      end

      alloc_version = Allocation.create!(params_copy)
    else
      alloc_version.update!(params_copy)
    end

    # Forward-populate the new allocations table
    self.allocate(
      case_info: CaseInformation.find_by(nomis_offender_id: params.fetch(:nomis_offender_id)),
      pom_detail: PomDetail.find_by(prison_code: params.fetch(:prison), nomis_staff_id: params.fetch(:primary_pom_nomis_id)),
      allocation_type: :primary, # this method is only used for primary allocations
      triggered_by_nomis_username: params.fetch(:created_by_username),
      metadata: {
        allocated_at_tier: params.fetch(:allocated_at_tier),
        recommended_pom_type: params.fetch(:recommended_pom_type),
        override_reasons: params.fetch(:override_reasons),
        override_detail: params.fetch(:override_detail),
        suitability_detail: params.fetch(:suitability_detail),
        pom_staff_id: primary_pom.staff_id,
        pom_first_name: primary_pom.first_name,
        pom_last_name: primary_pom.last_name,
        homd_first_name: created_by_user.first_name,
        homd_last_name: created_by_user.last_name,
        message_to_pom: params.fetch(:message)
      }
    )

    EmailService.instance(allocation: alloc_version,
                          message: params[:message],
                          pom_nomis_id: params[:primary_pom_nomis_id]).send_email

    delete_overrides(params[:primary_pom_nomis_id], params[:nomis_offender_id])

    alloc_version
  end

  def self.allocation_history_pom_emails(allocation)
    history = allocation.get_old_versions.append(allocation)
    pom_ids = history.map { |h| [h.primary_pom_nomis_id, h.secondary_pom_nomis_id] }.flatten.compact.uniq

    pom_ids.index_with { |pom_id| HmppsApi::PrisonApi::PrisonOffenderManagerApi.fetch_email_addresses(pom_id).first }
  end

  def self.create_override(params)
    Override.find_or_create_by(
      nomis_staff_id: params[:nomis_staff_id],
      nomis_offender_id: params[:nomis_offender_id]
    ).tap { |o|
      o.override_reasons = params[:override_reasons]
      o.suitability_detail = params[:suitability_detail]
      o.more_detail = params[:more_detail]
      o.save
    }
  end

  def self.current_allocation_for(nomis_offender_id)
    Allocation.allocations(nomis_offender_id).last
  end

private

  def self.delete_overrides(nomis_staff_id, nomis_offender_id)
    Override.where(
      nomis_staff_id: nomis_staff_id,
      nomis_offender_id: nomis_offender_id).
    destroy_all
  end
end
