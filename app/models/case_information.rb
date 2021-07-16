# frozen_string_literal: true

class CaseInformation < ApplicationRecord
  self.table_name = 'case_information'

  NPS = 'NPS'
  CRC = 'CRC'

  belongs_to :offender, foreign_key: :nomis_offender_id, inverse_of: :case_information

  belongs_to :local_delivery_unit, -> { enabled }, optional: true, inverse_of: :case_information
  delegate :name, :email_address, to: :local_delivery_unit, prefix: :ldu, allow_nil: true

  scope :nps, -> { where(case_allocation: NPS) }

  def nps_case?
    case_allocation == NPS
  end

  def welsh_offender
    probation_service == 'Wales'
  end

  def delius_matched?
    manual_entry == false
  end

  validates :manual_entry, inclusion: { in: [true, false], allow_nil: false }
  validates :nomis_offender_id, presence: true, uniqueness: true

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
