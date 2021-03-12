# frozen_string_literal: true

class Override
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::AttributeAssignment

  attribute :nomis_staff_id, :integer
  attribute :nomis_offender_id, :string

  attribute :more_detail, :string
  attribute :suitability_detail, :string
  attr_accessor :override_reasons

  attr_writer :session

  validates :nomis_staff_id, presence: {
    message: 'NOMIS Staff ID is required'
  }
  validates :nomis_offender_id, presence: {
    message: 'NOMIS Offender ID is required'
  }
  validates :override_reasons, presence: {
    message: 'Select one or more reasons for not accepting the recommendation'
  }
  validates :more_detail,
            presence: { message:
              'Please provide extra detail when Other is selected'
            },
            if: proc { |o|
                  o.override_reasons.present? && o.override_reasons.include?('other')
                },
            length: { maximum: 175,
                      too_long: 'This reason cannot be more than 175 characters'
            }

  validates :suitability_detail,
            presence: { message:
                            'Enter reason for allocating this POM'
            },
            if: proc { |o|
              o.override_reasons.present? && o.override_reasons.include?('suitability')
            },
            length: { maximum: 175,
                      too_long: 'This reason cannot be more than 175 characters'
            }
end
