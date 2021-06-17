# frozen_string_literal: true

class AllocationsController < PrisonsApplicationController
  before_action :ensure_spo_user, except: :history
  before_action :load_prisoner

  def show
    allocation = AllocationHistory.find_by!(nomis_offender_id: @prisoner.offender_no)
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
    prisoner = Offender.includes(case_information: :early_allocations).find_by(nomis_offender_id: nomis_offender_id_from_url)
    @case_info = prisoner.case_information if prisoner.present?
    @emails_sent_to_ldu = EmailHistory.sent_within_current_sentence(@prisoner, EmailHistory::OPEN_PRISON_COMMUNITY_ALLOCATION)
  end

  def history
    @prisoner = offender(nomis_offender_id_from_url)
    @timeline = HmppsApi::PrisonApi::MovementApi.movements_for nomis_offender_id_from_url

    allocation = AllocationHistory.find_by!(nomis_offender_id: nomis_offender_id_from_url)
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
    email_history = EmailHistory.in_offender_timeline.where(nomis_offender_id: nomis_offender_id_from_url)
    early_allocations = Offender.includes(case_information: :early_allocations).find_by!(nomis_offender_id: nomis_offender_id_from_url).case_information.early_allocations

    ea_history = early_allocations.map do |ea|
      if ea.updated_by_firstname.present?
        [EarlyAllocationHistory.new(ea), EarlyAllocationDecision.new(ea)]
      else
        [EarlyAllocationHistory.new(ea)]
      end
    end.flatten

    @history = (allocation_history(allocation) + vlo_history + complexity_history + email_history + ea_history).sort_by(&:created_at)
  end

private

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

  def offender(nomis_offender_id)
    OffenderService.get_offender(nomis_offender_id)
  end

  def nomis_offender_id_from_url
    params.require(:prisoner_id)
  end

  def load_prisoner
    @prisoner = OffenderService.get_offender(nomis_offender_id_from_url)
  end
end
