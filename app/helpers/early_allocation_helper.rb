# frozen_string_literal: true

module EarlyAllocationHelper
  def early_allocation_status_text(offender)
    {
      eligible: 'Eligible - case handover date has been updated',
      decision_pending: 'Discretionary - the community probation team will make a decision',
      assessment_saved: 'Has saved assessments',
      call_to_action: 'New assessment required',
    }.fetch(offender.early_allocation_state, 'Not assessed')
  end

  def early_allocation_action_link(offender, prison)
    case offender.early_allocation_state
    when :eligible
      most_recent = offender.early_allocations.last
      view_assessment = prison_prisoner_early_allocation_path(prison.code, offender.offender_no, most_recent.id)
      link_to 'View assessment', view_assessment
    when :decision_pending
      record_decision = edit_prison_prisoner_latest_early_allocation_path(prison.code, offender.offender_no)
      link_to 'Record community decision', record_decision
    when :assessment_saved, :call_to_action
      link_to 'Check and reassess', prison_prisoner_early_allocations_path(prison.code, offender.offender_no)
    else
      link_to 'Start assessment', prison_prisoner_early_allocations_path(prison.code, offender.offender_no)
    end
  end

  def early_allocation_outcome(early_allocation)
    if early_allocation.community_decision_eligible_or_automatically_eligible?
      'Eligible'
    elsif early_allocation.discretionary? && early_allocation.community_decision.nil?
      'Waiting for community decision'
    else
      'Not eligible'
    end
  end

  def early_allocation_long_outcome(early_allocation)
    if early_allocation.community_decision_eligible_or_automatically_eligible?
      if early_allocation.created_within_referral_window?
        'Eligible - the community probation team will take responsibility for this case early'
      else
        'Eligible - assessment not sent to the community probation team'
      end
    elsif early_allocation.community_decision_ineligible_or_automatically_ineligible?
      'Not eligible'
    elsif early_allocation.created_within_referral_window?
      'Discretionary - the community probation team will make a decision'
    else
      'Discretionary - assessment not sent to the community probation team'
    end
  end

  DESCRIPTIONS = {
      convicted_under_terrorisom_act_2000: 'Convicted under Terrorism Act 2000',
      high_profile: 'Identified as \'high profile\'',
      serious_crime_prevention_order: 'Has Serious Crime Prevention Order',
      mappa_level_3: 'Requires management as a Multi-Agency Public Protection (MAPPA) level 3',
      cppc_case: 'Likely to be a Critical Public Protection Case (CPPC)',
      extremism_separation: 'Has been held in an extremism separation centre',
      high_risk_of_serious_harm: 'Presents a very high risk of serious harm',
      mappa_level_2: 'Requires management as a Multi-Agency Public Protection (MAPPA) level 2',
      pathfinder_process: 'Identified through the \'pathfinder\' process',
      other_reason: 'Other reason for consideration for early allocation to the probation team',
  }.freeze

  def pom_full_name(early_allocation)
    "#{early_allocation.created_by_lastname}, #{early_allocation.created_by_firstname}"
  end

  EARLY_ALLOCATION_STATUSES = {
    eligible: 'ELIGIBLE',
    decision_pending: 'DECISION PENDING',
    assessment_saved: 'ASSESSMENT SAVED',
    # in status terms we don't care about the need to make a new assessment
    call_to_action: 'ASSESSMENT SAVED'
  }.freeze
end
