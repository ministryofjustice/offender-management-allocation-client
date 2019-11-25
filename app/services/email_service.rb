# frozen_string_literal: true

class EmailService
  def self.instance(message:, allocation:, pom_nomis_id:)
    new(allocation: allocation, message: message, pom_nomis_id: pom_nomis_id)
  end

  def initialize(message:, allocation:, pom_nomis_id:)
    @message = message
    @allocation = allocation

    @offender = OffenderService.get_offender(@allocation[:nomis_offender_id])
    @pom = PrisonOffenderManagerService.get_pom_at(
      @allocation.prison,
      pom_nomis_id
    )
  end

  def send_email
    return if @pom.emails.blank?

    if @allocation.event == 'reallocate_primary_pom' && previous_pom.present?
      send_deallocation_email
    end
    deliver_new_allocation_email
  end

  def send_coworking_primary_email(pom_firstname, coworking_pom_name)
    if @pom.emails.present?
      PomMailer.allocate_coworking_pom(
        message: @message,
        pom_name: pom_firstname.capitalize,
        offender_name: @offender.full_name,
        nomis_offender_id: @offender.offender_no,
        coworking_pom_name: coworking_pom_name,
        pom_email: @pom.emails.first,
        url: url
      ).deliver_later
    end
  end

  def send_secondary_email(pom_firstname)
    if @pom.emails.present?
      PomMailer.secondary_allocation_email(
        message: @message,
        pom_name: pom_firstname.capitalize,
        offender_name: @offender.full_name,
        nomis_offender_id: @offender.offender_no,
        responsibility: current_responsibility,
        responsible_pom_name: @allocation.primary_pom_name,
        pom_email: @pom.emails.first,
        url: url
      ).deliver_later
    end
  end

  def send_cowork_deallocation_email(secondary_pom_name)
    return if @pom.emails.blank?

    PomMailer.deallocate_coworking_pom(
      pom_name: @pom.first_name.capitalize,
      email_address: @pom.emails.first,
      secondary_pom_name: secondary_pom_name,
      nomis_offender_id: @offender.offender_no,
      offender_name: @offender.full_name,
      url: url
    ).deliver_later
  end

private

  def url
    @url ||= Rails.application.routes.url_helpers.prison_caseload_index_url(@allocation.prison)
  end

  def current_responsibility
    ResponsibilityService.
      calculate_pom_responsibility(@offender).to_s.downcase
  end

  def previous_pom
    # Check the versions (there MUST be previous records if this is a reallocation)
    # and find the last version with a primary_pom id that is not the same as the
    # allocation. That will be the POM that is notified of a reallocation.
    @previous_pom ||= begin
      versions = AllocationService.get_versions_for(@allocation)

      previous = versions.reverse.detect { |version|
        version.primary_pom_nomis_id.present? && version.primary_pom_nomis_id != @allocation.primary_pom_nomis_id
      }
      return nil if previous.blank?

      StaffMember.new(previous.primary_pom_nomis_id)
    end
  end

  def send_deallocation_email
    # If the previous pom does not have email configured, do not
    # try and email them.
    return if previous_pom.email_address.blank?

    PomMailer.deallocation_email(
      previous_pom_name: previous_pom.first_name.capitalize,
      responsibility: current_responsibility,
      previous_pom_email: previous_pom.email_address,
      new_pom_name: @pom.full_name,
      offender_name: @offender.full_name,
      offender_no: @offender.offender_no,
      prison: PrisonService.name_for(@pom.agency_id),
      url: url
    ).deliver_later
  end

  def deliver_new_allocation_email
    PomMailer.new_allocation_email(
      pom_name: @pom.first_name.capitalize,
      responsibility: current_responsibility,
      pom_email: @pom.emails.first,
      offender_name: @offender.full_name,
      offender_no: @offender.offender_no,
      message: @message,
      url: url
    ).deliver_later
  end
end
