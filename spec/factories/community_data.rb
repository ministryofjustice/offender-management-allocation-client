# frozen_string_literal: true

FactoryBot.define do
  factory :community_data, class: Hash do
    initialize_with { attributes }

    currentTier { 'A' }

    otherIds { { crn: 'X362207'} }

    offenderManagers { [ build(:community_offender_manager) ] }

    enhancedResourcing { true }

    trait :crc do
      enhancedResourcing { false }
    end

    trait :nps do
      enhancedResourcing { true }
    end
  end

  factory :community_offender_manager, class: Hash do
    initialize_with { attributes }

    active { true }
    probationArea { { nps: true } }
    staff { { unallocated: false, surname: 'Jones', forenames: 'Ruth Mary' } }
  end

  factory :community_registration, class: Hash do
    initialize_with { attributes }

    active { true }

    trait :mappa_2 do
      registerLevel {
        {
            code: 'M2',
            description: 'MAPPA Level 2'
        }
      }
    end
  end
end
