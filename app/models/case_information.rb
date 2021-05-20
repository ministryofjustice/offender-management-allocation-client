# frozen_string_literal: true

class CaseInformation < ApplicationRecord
  self.table_name = 'case_information'

  NPS = 'NPS'
  CRC = 'CRC'

  belongs_to :local_delivery_unit, optional: true

  has_many :new_allocations
  has_many :pom_details, through: :new_allocations

  has_many :early_allocations,
           -> { order(created_at: :asc) },
           foreign_key: :nomis_offender_id,
           primary_key: :nomis_offender_id,
           inverse_of: :case_information,
           dependent: :destroy

  has_many :victim_liaison_officers, dependent: :destroy

  scope :nps, -> { where(case_allocation: NPS) }

  has_one :responsibility,
          foreign_key: :nomis_offender_id,
          primary_key: :nomis_offender_id,
          inverse_of: :case_information,
          dependent: :destroy

  # This is quite a loose relationship. It exists so that CaseInformation
  # deletes cascade and tidy up associated CalculatedHandoverDate records.
  # Ideally CalculatedHandoverDate would belong to a higher-level
  # Offender model rather than nDelius Case Information
  has_one :calculated_handover_date,
          foreign_key: :nomis_offender_id,
          primary_key: :nomis_offender_id,
          inverse_of: :case_information,
          dependent: :destroy

  has_many :email_histories,
           foreign_key: :nomis_offender_id,
           primary_key: :nomis_offender_id,
           inverse_of: :case_information,
           dependent: :destroy

  def nps?
    case_allocation == NPS
  end

  # Only return the LDU if it's enabled
  def ldu
    if local_delivery_unit&.enabled?
      local_delivery_unit
    end
  end

  # We only normally show/edit the most recent early allocation
  def latest_early_allocation
    early_allocations.last
  end

  validates :manual_entry, inclusion: { in: [true, false], allow_nil: false }
  validates :nomis_offender_id, presence: true, uniqueness: true

  validates :local_delivery_unit, presence: true, unless: -> { manual_entry }

  # Don't think this is as simple as allowing nil. In the specific case of Scot/NI
  # prisoners it makes sense to have N/A (as this is genuine) but not otherwise
  validates :tier, inclusion: { in: %w[A B C D N/A], message: 'Select the prisoner’s tier' }

  validates :case_allocation, inclusion: {
    in: [NPS, CRC],
    allow_nil: false,
    message: 'Select the service provider for this case'
  }

  # nil means MAPPA level is completely unknown.
  # 0 means MAPPA level is known to be not relevant for offender
  validates :mappa_level, inclusion: { in: [0, 1, 2, 3], allow_nil: true }

  validates :probation_service, inclusion: {
    in: ['Wales', 'England'],
    allow_nil: false,
    message: 'Select yes if the prisoner’s last known address was in Wales'
  }
end
