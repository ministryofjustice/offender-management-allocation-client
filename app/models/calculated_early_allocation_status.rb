# frozen_string_literal: true

class CalculatedEarlyAllocationStatus < ApplicationRecord
  belongs_to :offender, foreign_key: :nomis_offender_id, inverse_of: :calculated_early_allocation_status
end
