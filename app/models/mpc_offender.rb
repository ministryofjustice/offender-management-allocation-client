# frozen_string_literal: true

class MpcOffender
  delegate :get_image,
           :convicted?, :recalled?, :immigration_case?, :indeterminate_sentence?,
           :sentenced?, :over_18?, :describe_sentence, :civil_sentence?,
           :sentence_start_date, :conditional_release_date, :automatic_release_date, :parole_eligibility_date,
           :tariff_date, :post_recall_release_date, :licence_expiry_date,
           :home_detention_curfew_actual_date, :home_detention_curfew_eligibility_date,
           :prison_arrival_date, :earliest_release_date, :latest_temp_movement_date, :release_date,
           :date_of_birth, :main_offence, :awaiting_allocation_for, :cell_location,
           :category_label, :complexity_level, :category_code, :category_active_since,
           :first_name, :last_name, :full_name_ordered, :full_name,
           :inside_omic_policy?, :offender_no, :prison_id, to: :@prison_record

  delegate :crn, :case_allocation, :manual_entry?, :nps_case?,
           :tier, :delius_matched?,
           :mappa_level, :welsh_offender, to: :probation_record

  delegate :victim_liaison_officers, to: :@offender

  # These fields make sense to be nil when the probation record is nil - the others dont
  delegate :ldu_email_address, :team_name, :ldu_name, to: :probation_record, allow_nil: true

  attr_reader :probation_record, :prison

  def initialize(prison:, offender:, prison_record:)
    @prison = prison
    @offender = offender
    @prison_record = prison_record
    @probation_record = offender.case_information
  end

  # TODO - view method in model needs to be removed
  def case_owner
    if pom_responsible?
      'Custody'
    else
      'Community'
    end
  end

  def needs_a_com?
    @probation_record.present? && (com_responsible? || com_supporting?) && allocated_com_name.blank?
  end

  def pom_responsible?
    if @offender.responsibility.nil?
      HandoverDateService.handover(self).custody_responsible?
    else
      @offender.responsibility.value == Responsibility::PRISON
    end
  end

  def pom_supporting?
    if @offender.responsibility.nil?
      HandoverDateService.handover(self).custody_supporting?
    else
      @offender.responsibility.value == Responsibility::PROBATION
    end
  end

  def com_responsible?
    if @offender.responsibility.nil?
      HandoverDateService.handover(self).community_responsible?
    else
      @offender.responsibility.value == Responsibility::PROBATION
    end
  end

  def com_supporting?
    if @offender.responsibility.nil?
      HandoverDateService.handover(self).community_supporting?
    else
      # Overrides to prison aren't actually possible in the UI
      # If they were, we'd somehow need to decide whether COM is supporting or not involved
      @offender.responsibility.value == Responsibility::PRISON
    end
  end

  def allocated_com_name
    @probation_record.com_name
  end

  def responsibility_override?
    @offender.responsibility.present?
  end

  # Early allocation methods
  def early_allocation?
    latest_early_allocation.present?
  end

  def latest_early_allocation
    allocation = early_allocations&.last
    allocation if allocation.present? && allocation.created_within_referral_window? && (allocation.eligible? || allocation.community_decision?)
  end

  def early_allocations
    @offender.early_allocations.where('created_at::date >= ?', sentence_start_date)
  end

  def needs_early_allocation_notify?
    # The probation_record.present? check is needed as one of the dates is PRD which is currently inside case_information
    @probation_record.present? &&
      within_early_allocation_window? &&
      early_allocations.active_pre_referral_window.any? &&
      early_allocations.post_referral_window.empty?
  end

  def within_early_allocation_window?
    earliest_date = [
      tariff_date,
      parole_eligibility_date,
      parole_review_date,
      automatic_release_date,
      conditional_release_date
    ].compact.min
    earliest_date.present? && earliest_date <= Time.zone.today + 18.months
  end

  # handover methods
  def handover_start_date
    handover.start_date
  end

  def handover_reason
    handover.reason_text
  end

  def responsibility_handover_date
    handover.handover_date
  end

  def approaching_handover?
    # we can't calculate handover without case info as we don't know NPS/CRC
    return false if @probation_record.blank?

    today = Time.zone.today
    thirty_days_time = today + 30.days

    start_date = handover_start_date
    handover_date = responsibility_handover_date

    return false if start_date.nil?

    if start_date.future?
      start_date.between?(today, thirty_days_time)
    else
      today.between?(start_date, handover_date)
    end
  end

  def parole_review_date
    @offender.parole_record.parole_review_date if @offender.parole_record.present?
  end

private

  def handover
    @handover ||= if pom_responsible?
                    HandoverDateService.handover(self)
                  else
                    HandoverDateService::NO_HANDOVER_DATE
                  end
  end
end
