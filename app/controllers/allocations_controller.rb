# frozen_string_literal: true

class AllocationsController < PrisonsApplicationController
  before_action :ensure_spo_user, except: :history

  delegate :update, to: :create

  def index
    offender_id = params.require(:prisoner_id)
    @prisoner = offender(offender_id)
    @recommended_poms, @not_recommended_poms =
      recommended_and_nonrecommended_poms_for(@prisoner)
    @unavailable_pom_count = unavailable_pom_count
    @allocation = Allocation.find_by nomis_offender_id: offender_id
    @previously_allocated_pom_ids =
      @allocation.present? ? @allocation.previously_allocated_poms : []
    @case_info = CaseInformation.includes(:early_allocations).find_by(nomis_offender_id: offender_id)
    @emails_sent_to_ldu = EmailHistory.sent_within_current_sentence(@prisoner, EmailHistory::OPEN_PRISON_COMMUNITY_ALLOCATION)
  end

  def show
    @prisoner = offender(nomis_offender_id_from_url)

    allocation = Allocation.find_by!(nomis_offender_id: @prisoner.offender_no)
    @allocation = CaseHistory.new(allocation.get_old_versions.last, allocation, allocation.versions.last)

    @pom = StaffMember.new(@prison, @allocation.primary_pom_nomis_id)
    redirect_to prison_pom_non_pom_path(@prison.code, @pom.staff_id) unless @pom.has_pom_role?

    secondary_pom_nomis_id = @allocation.secondary_pom_nomis_id
    if secondary_pom_nomis_id.present?
      coworker = StaffMember.new(@prison, secondary_pom_nomis_id)
      if coworker.has_pom_role?
        @coworker = coworker
      end
    end
    @keyworker = HmppsApi::KeyworkerApi.get_keyworker(active_prison_id, @prisoner.offender_no)
    @case_info = CaseInformation.includes(:early_allocations).find_by(nomis_offender_id: nomis_offender_id_from_url)
    @emails_sent_to_ldu = EmailHistory.sent_within_current_sentence(@prisoner, EmailHistory::OPEN_PRISON_COMMUNITY_ALLOCATION)
  end

  def edit
    @allocation = AllocationService.current_allocation_for(nomis_offender_id_from_url)

    unless @allocation.present? && @allocation.active?
      redirect_to prison_prisoner_staff_index_path(active_prison_id, nomis_offender_id_from_url)
      return
    end

    @prisoner = offender(nomis_offender_id_from_url)
    @previously_allocated_pom_ids = @allocation.previously_allocated_poms
    @recommended_poms, @not_recommended_poms =
      recommended_and_nonrecommended_poms_for(@prisoner)
    @unavailable_pom_count = unavailable_pom_count

    @current_pom = current_pom_for(nomis_offender_id_from_url)
    @case_info = CaseInformation.includes(:early_allocations).find_by(nomis_offender_id: nomis_offender_id_from_url)
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
        "#{offender.full_name_ordered} has been allocated to #{view_context.full_name_ordered(pom)} (#{view_context.grade(pom)})"
    else
      flash[:alert] =
        "#{offender.full_name_ordered} has not been allocated  - please try again"
    end

    if allocation[:event] == 'allocate_primary_pom'
      redirect_to unallocated_prison_prisoners_path(active_prison_id, page: params[:page], sort: params[:sort])
    else
      redirect_to allocated_prison_prisoners_path(active_prison_id, page: params[:page], sort: params[:sort])
    end
  end

  def history
    @prisoner = offender(nomis_offender_id_from_url)

    allocation = Allocation.find_by!(nomis_offender_id: nomis_offender_id_from_url)
    vlo_history = PaperTrail::Version.
        where(item_type: 'VictimLiaisonOfficer', nomis_offender_id: nomis_offender_id_from_url).map { |vlo_version| VloHistory.new(vlo_version) }
    complexity_history = if @prison.womens?
                           hists = HmppsApi::ComplexityApi.get_history(nomis_offender_id_from_url)
                           if hists.any?
                             [ComplexityNewHistory.new(hists.first)] +
                               hists.each_cons(2).map { |hpair|
                                 ComplexityChangeHistory.new(hpair.first, hpair.second)
                               }
                           end
                         end
    complexity_history = [] if complexity_history.nil?

    @history = (allocation_history(allocation) + new_allocation_history + vlo_history + complexity_history).sort_by(&:created_at)
    @early_allocations = CaseInformation.find_by!(nomis_offender_id: nomis_offender_id_from_url).early_allocations
    @email_histories = EmailHistory.in_offender_timeline.where(nomis_offender_id: nomis_offender_id_from_url)

    @pom_emails = AllocationService.allocation_history_pom_emails(allocation)
  end

private

  def new_allocation_history
    OffenderEvent.where(nomis_offender_id: nomis_offender_id_from_url)
                 .where(event: [:allocate_primary_pom, :allocate_coworking_pom, :reallocate_primary_pom, :reallocate_coworking_pom])
                 .map { |event| NewCaseHistory.new(event) }
  end

  # Gets the versions in *forward* order - so often we want to reverse
  # this list as we're interested in recent rather than ancient history
  def allocation_history allocation
    version_pairs = allocation.get_old_versions.append(allocation).zip(allocation.versions)

    # make CaseHistory records which contain the previous and current allocation history
    # records - so that deallocation can look at the old version to work out the POM name and ID
    [CaseHistory.new(nil, version_pairs.first.first, version_pairs.first.second)] +
      version_pairs.each_cons(2).map do |prev_pair, curr_pair|
        CaseHistory.new(prev_pair.first, curr_pair.first, curr_pair.second)
      end
  end

  def unavailable_pom_count
    PrisonOffenderManagerService.get_poms_for(active_prison_id).count { |pom| pom.status != 'active' }
  end

  def allocation_attributes(offender)
    {
      primary_pom_nomis_id: allocation_params[:nomis_staff_id].to_i,
      nomis_offender_id: allocation_params[:nomis_offender_id],
      event: allocation_params[:event],
      event_trigger: allocation_params[:event_trigger],
      created_by_username: current_user,
      allocated_at_tier: offender.tier,
      recommended_pom_type: (RecommendationService.recommended_pom_type(offender) == RecommendationService::PRISON_POM) ? 'prison' : 'probation',
      prison: active_prison_id,
      override_reasons: override_reasons,
      suitability_detail: suitability_detail,
      override_detail: override_detail,
      message: allocation_params[:message]
    }
  end

  def offender(nomis_offender_id)
    OffenderService.get_offender(nomis_offender_id)
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
    nomis_staff_id = Allocation.find_by!(nomis_offender_id: nomis_offender_id).primary_pom_nomis_id

    PrisonOffenderManagerService.get_pom_at(active_prison_id, nomis_staff_id)
  end

  def recommended_and_nonrecommended_poms_for(offender)
    allocation = Allocation.find_by(nomis_offender_id: offender.offender_no)
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
