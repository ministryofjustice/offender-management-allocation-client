# frozen_string_literal: true

class OverridesController < PrisonsApplicationController
  include Wicked::Wizard

  steps :override_reason, :enter_message

  def new
    #@prisoner = offender(params.require(:nomis_offender_id))
    #@pom = PrisonOffenderManagerService.get_pom_at(active_prison_id, params[:nomis_staff_id])
    #
    #@override = Override.new
    session[:allocation_override] = Override.new nomis_staff_id: params.fetch(:nomis_staff_id),
                                      nomis_offender_id: params.fetch(:nomis_offender_id)

    redirect_to wizard_path(steps.first)
  end

  def show
    @override = Override.new session[:allocation_override]
    @pom = PrisonOffenderManagerService.get_pom_at(active_prison_id, @override.nomis_staff_id)
    @prisoner = offender(@override.nomis_offender_id)

    render_wizard
  end

  def update
    @override = Override.new session[:allocation_override]
    @prisoner = offender(@override.nomis_offender_id)
    @pom = PrisonOffenderManagerService.get_pom_at(active_prison_id, @override.nomis_staff_id)

    if step != wizard_steps.last
      @override.assign_attributes override_params
      if @override.valid?
        redirect_to next_wizard_path
      else
        render_wizard
      end
    else
      allocation = {
          primary_pom_nomis_id: @override.nomis_staff_id,
          nomis_offender_id: @override.nomis_offender_id,
          nomis_booking_id: @prisoner.booking_id,
          event: :allocate_primary_pom,
          event_trigger: :user,
          created_by_username: current_user,
          allocated_at_tier: @prisoner.tier,
          recommended_pom_type: (@prisoner.recommended_pom_type == RecommendationService::PRISON_POM) ? 'prison' : 'probation',
          prison: active_prison_id,
          override_reasons: @override.override_reasons,
          suitability_detail: @override.suitability_detail,
          override_detail: @override.more_detail,
          message: allocation_params[:message]
      }

      AllocationService.create_or_update(allocation)
      flash[:notice] = "#{@prisoner.full_name_ordered} has been allocated to #{@pom.full_name_ordered} (#{@pom.grade})"

      redirect_to prison_summary_unallocated_path(active_prison_id, page: params[:page], sort: params[:sort])
    end
  end

  #def create
  #  @override = AllocationService.create_override(override_params)
  #
  #  return redirect_on_success if @override.valid?
  #
  #  @prisoner = offender(override_params[:nomis_offender_id])
  #  @pom = PrisonOffenderManagerService.get_pom_at(
  #    active_prison_id, override_params[:nomis_staff_id])
  #
  #  render :new
  #end

private

  def allocation_params
    params.require(:allocations).permit(:message, :nomis_offender_id, :nomis_staff_id, :event, :event_trigger)
  end

  def offender(nomis_offender_id)
    OffenderService.get_offender(nomis_offender_id)
  end

  def override_params
    params.require(:override).permit(
      :nomis_offender_id,
      :nomis_staff_id,
      :more_detail,
      :suitability_detail,
      override_reasons: []
    )
  end
end
