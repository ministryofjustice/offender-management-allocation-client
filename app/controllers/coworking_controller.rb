# frozen_string_literal: true

class CoworkingController < PrisonsApplicationController
  def new
    @prisoner = offender(nomis_offender_id_from_url)
    current_pom_id = Allocation.find_by!(nomis_offender_id: nomis_offender_id_from_url).primary_pom_nomis_id
    poms = PrisonOffenderManagerService.get_poms_for(active_prison_id)
    @current_pom = poms.detect { |pom| pom.staff_id == current_pom_id }

    @active_poms, @unavailable_poms = poms.reject { |p| p.staff_id == current_pom_id }.partition { |pom|
      %w[active unavailable].include? pom.status
    }

    @prison_poms = @active_poms.select(&:prison_officer?)
    @probation_poms = @active_poms.select(&:probation_officer?)
    @case_info = CaseInformation.includes(:early_allocations).find_by(nomis_offender_id: nomis_offender_id_from_url)
  end

  def confirm
    @prisoner = offender(nomis_offender_id_from_url)
    @primary_pom = PrisonOffenderManagerService.get_pom_at(
      active_prison_id, primary_pom_id_from_url
    )
    @secondary_pom = PrisonOffenderManagerService.get_pom_at(
      active_prison_id, secondary_pom_id_from_url
    )
  end

  def create
    offender = offender(allocation_params[:nomis_offender_id])
    pom = PrisonOffenderManagerService.get_pom_at(
      active_prison_id,
      allocation_params[:nomis_staff_id]
    )

    AllocationService.allocate_secondary(
      nomis_offender_id: allocation_params[:nomis_offender_id],
      secondary_pom_nomis_id: allocation_params[:nomis_staff_id],
      pom_detail: PomDetail.find_by(prison_code: active_prison_id, nomis_staff_id: allocation_params[:nomis_staff_id]),
      created_by_username: current_user,
      message: allocation_params[:message]
    )
    redirect_to unallocated_prison_prisoners_path(active_prison_id),
                notice: "#{offender.full_name_ordered} has been allocated to #{view_context.full_name_ordered(pom)} (#{view_context.grade(pom)})"
  end

  def confirm_removal
    @prisoner = offender(coworking_nomis_offender_id_from_url)

    @allocation = Allocation.find_by!(
      nomis_offender_id: coworking_nomis_offender_id_from_url
    )
    @primary_pom = PrisonOffenderManagerService.get_pom_at(
      active_prison_id, @allocation.primary_pom_nomis_id
    )
  end

  def destroy
    # Deallocate 'new' allocation
    case_info = CaseInformation.find_by!(nomis_offender_id: nomis_offender_id_from_url)
    AllocationService.deallocate(case_info: case_info, allocation_type: :coworking)

    # Deallocate 'old' allocation
    @allocation = Allocation.find_by!(
      nomis_offender_id: nomis_offender_id_from_url
    )

    secondary_pom_name = @allocation.secondary_pom_name

    @allocation.update!(
      secondary_pom_name: nil,
      secondary_pom_nomis_id: nil,
      event: Allocation::DEALLOCATE_SECONDARY_POM,
      event_trigger: Allocation::USER
    )

    # stop double-bounces from sending invalid emails.
    if secondary_pom_name.present?
      EmailService.instance(allocation: @allocation,
                            message: '',
                            pom_nomis_id: @allocation.primary_pom_nomis_id
      ).send_cowork_deallocation_email(secondary_pom_name)
    end

    redirect_to prison_allocation_path(active_prison_id, nomis_offender_id_from_url)
  end

private

  def allocation_params
    params.require(:coworking_allocations).
      permit(:message, :nomis_offender_id, :nomis_staff_id)
  end

  def offender(nomis_offender_id)
    OffenderService.get_offender(nomis_offender_id)
  end

  def coworking_nomis_offender_id_from_url
    params.require(:coworking_nomis_offender_id)
  end

  def nomis_offender_id_from_url
    params.require(:nomis_offender_id)
  end

  def secondary_pom_id_from_url
    params.require(:secondary_pom_id)
  end

  def primary_pom_id_from_url
    params.require(:primary_pom_id)
  end
end
