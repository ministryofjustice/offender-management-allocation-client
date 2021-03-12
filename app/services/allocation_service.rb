# frozen_string_literal: true

class AllocationService
  def self.allocate_secondary(
    nomis_offender_id:,
    secondary_pom_nomis_id:,
    created_by_username:,
    message:
  )
    alloc_version = Allocation.find_by!(
      nomis_offender_id: nomis_offender_id
    )

    pom_firstname, _pom_secondname =
      PrisonOffenderManagerService.get_pom_name(alloc_version.primary_pom_nomis_id)
    coworking_pom_firstname, coworking_pom_secondname =
      PrisonOffenderManagerService.get_pom_name(secondary_pom_nomis_id)
    user_firstname, user_secondname =
      PrisonOffenderManagerService.get_user_name(created_by_username)

    alloc_version.update!(
      secondary_pom_name: "#{coworking_pom_secondname}, #{coworking_pom_firstname}",
      created_by_name: "#{user_firstname} #{user_secondname}",
      secondary_pom_nomis_id: secondary_pom_nomis_id,
      event: Allocation::ALLOCATE_SECONDARY_POM,
      event_trigger: Allocation::USER
    )

    EmailService.instance(allocation: alloc_version, message: message,
                          pom_nomis_id: alloc_version.primary_pom_nomis_id).
      send_coworking_primary_email(pom_firstname, alloc_version.secondary_pom_name)

    EmailService.instance(allocation: alloc_version, message: message,
                          pom_nomis_id: secondary_pom_nomis_id).
      send_secondary_email(coworking_pom_firstname)
  end

  def self.create_or_update(params)
    pom_firstname, pom_secondname =
      PrisonOffenderManagerService.get_pom_name(params[:primary_pom_nomis_id])
    user_firstname, user_secondname =
      PrisonOffenderManagerService.get_user_name(params[:created_by_username])

    params_copy = params.except(:created_by_username).merge(
      primary_pom_name: "#{pom_secondname}, #{pom_firstname}",
      created_by_name: "#{user_firstname} #{user_secondname}",
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

    EmailService.instance(allocation: alloc_version,
                          message: params[:message],
                          pom_nomis_id: params[:primary_pom_nomis_id]).send_email

    alloc_version
  end

  def self.active_allocations(nomis_offender_ids, prison)
    Allocation.active(nomis_offender_ids, prison).index_by { |a|
      a[:nomis_offender_id]
    }
  end

  def self.previously_allocated_poms(nomis_offender_id)
    allocation = Allocation.find_by(nomis_offender_id: nomis_offender_id)

    return [] if allocation.nil?

    allocation.get_old_versions.map(&:primary_pom_nomis_id)
  end

  def self.allocation_history_pom_emails(allocation)
    history = allocation.get_old_versions.append(allocation)
    pom_ids = history.map { |h| [h.primary_pom_nomis_id, h.secondary_pom_nomis_id] }.flatten.compact.uniq

    pom_ids.index_with { |pom_id| PrisonOffenderManagerService.get_pom_emails(pom_id).first }
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

  def self.current_pom_for(nomis_offender_id, prison_id)
    current_allocation = active_allocations(nomis_offender_id, prison_id)
    nomis_staff_id = current_allocation[nomis_offender_id].primary_pom_nomis_id

    PrisonOffenderManagerService.get_pom_at(prison_id, nomis_staff_id)
  end
end
