# frozen_string_literal: true

class AllocationService
  def self.allocate_secondary(
    nomis_offender_id:,
    secondary_pom_nomis_id:,
    created_by_username:,
    message:
  )
    alloc_version = AllocationHistory.find_by!(
      nomis_offender_id: nomis_offender_id
    )

    coworking_pom = HmppsApi::PrisonApi::PrisonOffenderManagerApi.staff_detail(secondary_pom_nomis_id)

    created_by_user = HmppsApi::PrisonApi::UserApi.user_details(created_by_username)

    alloc_version.update!(
      secondary_pom_name: "#{coworking_pom.last_name}, #{coworking_pom.first_name}",
      created_by_name: "#{created_by_user.first_name} #{created_by_user.last_name}",
      secondary_pom_nomis_id: secondary_pom_nomis_id,
      event: AllocationHistory::ALLOCATE_SECONDARY_POM,
      event_trigger: AllocationHistory::USER
    )

    EmailService.send_coworking_primary_email(allocation: alloc_version, message: message)

    EmailService.send_secondary_email(allocation: alloc_version, message: message,
                          pom_nomis_id: secondary_pom_nomis_id, pom_firstname: coworking_pom.first_name)
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
    alloc_version = AllocationHistory.find_by(
      nomis_offender_id: params_copy[:nomis_offender_id]
    )

    if alloc_version.nil?
      if AllocationHistory.where(prison: params_copy[:prison]).empty?
        PomMailer.new_prison_allocation_email(params_copy[:prison]).deliver_later
      end

      alloc_version = AllocationHistory.create!(params_copy)
    else
      alloc_version.update!(params_copy)
    end

    EmailService.send_email(allocation: alloc_version,
                          message: params[:message],
                          pom_nomis_id: params[:primary_pom_nomis_id])

    alloc_version
  end

  def self.allocation_history_pom_emails(allocation)
    history = allocation.get_old_versions.append(allocation)
    pom_ids = history.map { |h| [h.primary_pom_nomis_id, h.secondary_pom_nomis_id] }.flatten.compact.uniq

    pom_ids.index_with { |pom_id| HmppsApi::PrisonApi::PrisonOffenderManagerApi.fetch_email_addresses(pom_id).first }
  end
end
