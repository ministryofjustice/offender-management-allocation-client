class NewAllocation < ApplicationRecord
  belongs_to :pom_detail
  belongs_to :case_information

  enum allocation_type: { primary: 'primary', coworking: 'coworking' }

  validates :pom_detail, :case_information, presence: true
  validates :allocation_type, inclusion: { in: allocation_types.keys }
  validates :case_information, presence: true,
            uniqueness: { scope: :allocation_type, message: 'The offender already has an allocation of that type' }
end
