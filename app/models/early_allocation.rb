# frozen_string_literal: true

class EarlyAllocation < ApplicationRecord
  before_save :record_outcome

  belongs_to :case_information,
             primary_key: :nomis_offender_id,
             foreign_key: :nomis_offender_id,
             inverse_of: :early_allocations

  validates_presence_of :prison, :created_by_firstname, :created_by_lastname

  validates :oasys_risk_assessment_date,
            presence: true,
            date: {
              before: proc { Time.zone.today },
              after: proc { Time.zone.today - 3.months },
              # validating presence, so stop date validator double-checking
              allow_nil: true
            }

  # nomis_offender_ids of offenders who have assessments completed before 18 months prior to their release date, where
  # the assessment outcomes are 'discretionary' or 'eligible'
  scope :suitable_offenders_pre_referral_window, -> {
    where(created_within_referral_window: false).where.not(outcome: 'ineligible').pluck(:nomis_offender_id).uniq
  }

  STAGE1_BOOLEAN_FIELDS = [:convicted_under_terrorisom_act_2000,
                           :high_profile,
                           :serious_crime_prevention_order,
                           :mappa_level_3,
                           :cppc_case].freeze

  STAGE1_BOOLEAN_FIELDS.each do |field|
    validates(field, inclusion: {
                in: [true, false],
                allow_nil: false
              })
  end

  STAGE1_FIELDS = [:oasys_risk_assessment_date] + STAGE1_BOOLEAN_FIELDS

  def any_stage1_field_errors?
    STAGE1_FIELDS.map { |f| errors.include?(f) }.any?
  end

  validate :validate_stage1, unless: -> { stage2_validation || stage3_validation || recording_community_decision }

  # add an arbitrary error in stage1 if we're not eligible. This will push us onto stage2
  # by asking any_stage1_field_errors? and prevent the save.
  def validate_stage1
    errors.add(:stage2_validation, 'cant save') unless stage1_eligible?
  end

  attribute :stage2_validation, :boolean

  STAGE2_COMMON_FIELDS = [:high_risk_of_serious_harm,
                          :mappa_level_2,
                          :pathfinder_process,
                          :other_reason].freeze

  STAGE2_PLAIN_BOOLEAN_FIELDS = ([:extremism_separation] + STAGE2_COMMON_FIELDS).freeze

  STAGE2_BOOLEAN_FIELDS = (STAGE2_COMMON_FIELDS + [:due_for_release_in_less_than_24months]).freeze

  # stage2 boolean fields are all nullable(i.e. tri-state) booleans, so beware querying them.
  ALL_STAGE2_FIELDS = (STAGE2_COMMON_FIELDS + [:extremism_separation, :due_for_release_in_less_than_24months]).freeze

  STAGE2_PLAIN_BOOLEAN_FIELDS.each do |field|
    validates(field, inclusion: {
                in: [true, false],
                allow_nil: false
              }, if: -> { stage2_validation })
  end

  # This field is only prompted for if extremism_separation is true
  validates(:due_for_release_in_less_than_24months, inclusion: {
              in: [true, false],
              allow_nil: false }, if: -> { extremism_separation })

  def any_stage2_field_errors?
    ALL_STAGE2_FIELDS.map { |f| errors.include?(f) }.any?
  end

  validate :validate_stage2, if: -> { stage2_validation  }

  # add an arbitrary error in stage2 if we're not savable i.e. in discretionary state
  def validate_stage2
    errors.add(:stage2_validation, 'cant save') if discretionary?
  end

  attribute :stage3_validation, :boolean

  validates :reason, presence: true, if: -> { stage3_validation }

  # approved checkbox must be ticked for final completion
  validates :approved, inclusion: { in: [true],
                                    allow_nil: false
                                    }, if: -> { stage3_validation }

  attribute :recording_community_decision, :boolean
  validates :community_decision,
            inclusion: { in: [true, false], allow_nil: false },
            if: -> { recording_community_decision }

  def eligible?
    stage1_eligible?
  end

  def ineligible?
    !stage1_eligible? && (all_stage2_false? || (extremism_separation && !due_for_release_in_less_than_24months))
  end

  def discretionary?
    !eligible? && !ineligible?
  end

  def awaiting_community_decision?
    created_within_referral_window? && discretionary? && community_decision.nil?
  end

private

  def stage1_eligible?
    # If any of the 5 stage1 booleans is a yes, then early allocation answer is 'yes'
    STAGE1_BOOLEAN_FIELDS.map(&method(:public_send)).any?
  end

  def all_stage2_false?
    STAGE2_PLAIN_BOOLEAN_FIELDS.map(&method(:public_send)).none?
  end

  def record_outcome
    return self.outcome = 'eligible' if eligible?
    return self.outcome = 'ineligible' if ineligible?

    self.outcome = 'discretionary'
  end
end
