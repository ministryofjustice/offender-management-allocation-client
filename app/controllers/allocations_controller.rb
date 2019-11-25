# frozen_string_literal: true

class AllocationsController < PrisonsApplicationController
  before_action :ensure_admin_user

  delegate :update, to: :create

  breadcrumb 'Allocated', -> { prison_summary_allocated_path(active_prison_id) }, only: [:show]
  breadcrumb -> { offender(nomis_offender_id_from_url).full_name },
             -> { prison_allocation_path(active_prison_id, nomis_offender_id_from_url) }, only: [:show]

  def new
    @prisoner = offender(nomis_offender_id_from_url)
    @previously_allocated_pom_ids =
      AllocationService.previously_allocated_poms(nomis_offender_id_from_url)
    @recommended_poms, @not_recommended_poms =
      recommended_and_nonrecommended_poms_for(@prisoner)
    @unavailable_pom_count = unavailable_pom_count
  end

  def show
    @prisoner = offender(nomis_offender_id_from_url)

    @allocation = Allocation.find_by(nomis_offender_id: @prisoner.offender_no)
    @pom = StaffMember.new(@allocation.primary_pom_nomis_id)
    redirect_to prison_pom_non_pom_path(@prison.code, @pom.staff_id) unless @pom.pom_at?(@prison.code)

    secondary_pom_nomis_id = @allocation.secondary_pom_nomis_id
    unless secondary_pom_nomis_id.nil?
      @coworker = StaffMember.new(secondary_pom_nomis_id)
      redirect_to prison_pom_non_pom_path(@prison, @coworker.staff_id) unless @coworker.pom_at?(@prison.code)
    end
    @keyworker = Nomis::Keyworker::KeyworkerApi.get_keyworker(active_prison_id, @prisoner.offender_no)
  end

  def edit
    allocation = AllocationService.current_allocation_for(nomis_offender_id_from_url)

    unless allocation.present? && allocation.active?
      redirect_to new_prison_allocation_path(active_prison_id, nomis_offender_id_from_url)
      return
    end

    @prisoner = offender(nomis_offender_id_from_url)
    @previously_allocated_pom_ids =
      AllocationService.previously_allocated_poms(nomis_offender_id_from_url)
    @recommended_poms, @not_recommended_poms =
      recommended_and_nonrecommended_poms_for(@prisoner)
    @unavailable_pom_count = unavailable_pom_count

    @current_pom = current_pom_for(nomis_offender_id_from_url)
  end

  def confirm
    @prisoner = offender(nomis_offender_id_from_url)
    @pom = PrisonOffenderManagerService.get_pom_at(
      active_prison_id,
      nomis_staff_id_from_url
    )
    @event = :allocate_primary_pom
    @event_trigger = :user
  end

  def confirm_reallocation
    @prisoner = offender(nomis_offender_id_from_url)
    @pom = PrisonOffenderManagerService.get_pom_at(
      active_prison_id,
      nomis_staff_id_from_url
    )
    @event = :reallocate_primary_pom
    @event_trigger = :user
  end

  # Note #update is delegated to #create
  def create
    offender = offender(allocation_params[:nomis_offender_id])
    @override = override
    allocation = allocation_attributes(offender)

    if AllocationService.create_or_update(allocation)
      flash[:notice] =
        "#{offender.full_name_ordered} has been allocated to #{pom.full_name_ordered} (#{pom.grade})"
    else
      flash[:alert] =
        "#{offender.full_name_ordered} has not been allocated  - please try again"
    end

    if allocation[:event] == 'allocate_primary_pom'
      redirect_to prison_summary_unallocated_path(active_prison_id, page: params[:page], sort: params[:sort])
    else
      redirect_to prison_summary_allocated_path(active_prison_id, page: params[:page], sort: params[:sort])
    end
  end

  def history
    @prisoner = offender(nomis_offender_id_from_url)
    history = offender_allocation_history(nomis_offender_id_from_url)
    # The history is now collected forwards (to incorporate nil prison ids) but as a result
    # needs to be 'deep reversed' in order to work properly (as AllocationList produces a list of lists)
    @history = AllocationList.new(history).to_a.reverse.map { |prison, allocations| [prison, allocations.reverse] }
    @pom_emails = AllocationService.allocation_history_pom_emails(history)
  end

private

  def offender_allocation_history(nomis_offender_id)
    current_allocation = Allocation.find_by(nomis_offender_id: nomis_offender_id)

    unless current_allocation.nil?
      # we need to overwrite the 'updated_at' in the history with the 'to' value (index 1)
      # so that if it is changed later w/o history (e.g. by updating the COM name)
      # we don't produce the wrong answer
      allocs = AllocationService.get_versions_for(current_allocation).
        append(current_allocation)
      allocs.zip(current_allocation.versions).each do |alloc, raw_version|
        alloc.updated_at = YAML.load(raw_version.object_changes).fetch('updated_at')[1]
      end
      allocs
    end
  end

  def unavailable_pom_count
    @unavailable_pom_count ||= PrisonOffenderManagerService.unavailable_pom_count(
      active_prison_id
    )
  end

  def allocation_attributes(offender)
    {
      primary_pom_nomis_id: allocation_params[:nomis_staff_id].to_i,
      nomis_offender_id: allocation_params[:nomis_offender_id],
      event: allocation_params[:event],
      event_trigger: allocation_params[:event_trigger],
      created_by_username: current_user,
      nomis_booking_id: offender.booking_id,
      allocated_at_tier: offender.tier,
      recommended_pom_type: recommended_pom_type(offender),
      prison: active_prison_id,
      override_reasons: override_reasons,
      suitability_detail: suitability_detail,
      override_detail: override_detail,
      message: allocation_params[:message]
    }
  end

  def offender(nomis_offender_id)
    OffenderPresenter.new(OffenderService.get_offender(nomis_offender_id),
                          Responsibility.find_by(nomis_offender_id: nomis_offender_id))
  end

  def pom
    @pom ||= PrisonOffenderManagerService.get_pom_at(
      active_prison_id,
      allocation_params[:nomis_staff_id]
    )
  end

  def override
    Override.where(
      nomis_offender_id: allocation_params[:nomis_offender_id]).
      where(nomis_staff_id: allocation_params[:nomis_staff_id]).last
  end

  def current_pom_for(nomis_offender_id)
    current_allocation = AllocationService.active_allocations(nomis_offender_id, active_prison_id)
    nomis_staff_id = current_allocation[nomis_offender_id]['primary_pom_nomis_id']

    PrisonOffenderManagerService.get_pom_at(active_prison_id, nomis_staff_id)
  end

  def recommended_pom_type(offender)
    rec_type = RecommendationService.recommended_pom_type(offender)
    rec_type == RecommendationService::PRISON_POM ? 'prison' : 'probation'
  end

  def recommended_and_nonrecommended_poms_for(offender)
    allocation = Allocation.find_by(nomis_offender_id: nomis_offender_id_from_url)
    # don't allow primary to be the same as the co-working POM
    poms = PrisonOffenderManagerService.get_poms_for(active_prison_id).select { |pom|
      pom.status == 'active' && pom.staff_id != allocation.try(:secondary_pom_nomis_id)
    }

    recommended_poms(offender, poms)
  end

  def recommended_poms(offender, poms)
    # Returns a pair of lists where the first element contains the
    # POMs from the `poms` parameter that are recommended for the
    # `offender`
    recommended_type = RecommendationService.recommended_pom_type(offender)
    poms.partition { |pom|
      if recommended_type == RecommendationService::PRISON_POM
        pom.prison_officer?
      else
        pom.probation_officer?
      end
    }
  end

  def nomis_offender_id_from_url
    params.require(:nomis_offender_id)
  end

  def nomis_staff_id_from_url
    params.require(:nomis_staff_id)
  end

  def allocation_params
    params.require(:allocations).permit(
      :nomis_staff_id,
      :nomis_offender_id,
      :message,
      :event,
      :event_trigger
    )
  end

  def override_reasons
    @override[:override_reasons] if @override.present?
  end

  def override_detail
    @override[:more_detail] if @override.present?
  end

  def suitability_detail
    @override[:suitability_detail] if @override.present?
  end
end
