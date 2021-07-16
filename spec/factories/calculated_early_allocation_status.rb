# frozen_string_literal: true

FactoryBot.define do
  factory :calculated_early_allocation_status do
    nomis_offender_id { "MyString" }
    eligible { false }
  end
end
