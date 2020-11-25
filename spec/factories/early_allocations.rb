FactoryBot.define do
  # This object lives in 3 states - eligible, ineligible and discretionary(dont know)
  # The default for this factory is to make the object eligible
  factory :early_allocation do
    prison { 'LEI' }
    created_by_firstname { Faker::Name.first_name }
    created_by_lastname { Faker::Name.last_name }

    oasys_risk_assessment_date { Time.zone.today - 2.months }

    convicted_under_terrorisom_act_2000 { false }
    high_profile { false }
    serious_crime_prevention_order { false }
    mappa_level_3 { false }
    cppc_case { true }
    stage2_validation { false }
    created_within_referral_window { true }

    association :case_information

    trait :eligible do
      # Does nothing - eligible is the default outcome of early-allocation
    end

    trait :discretionary do
      cppc_case { false }
      extremism_separation { false }
      high_risk_of_serious_harm { false }
      mappa_level_2 do false end
      pathfinder_process do false end
      other_reason do true end
      reason { 'Just a reason' }
      approved { true }
      stage3_validation { true }
    end

    trait :discretionary_accepted do
      discretionary
      community_decision { true }
      updated_by_firstname { Faker::Name.first_name }
      updated_by_lastname { Faker::Name.last_name }
    end

    trait :discretionary_declined do
      discretionary
      community_decision { false }
      updated_by_firstname { Faker::Name.first_name }
      updated_by_lastname { Faker::Name.last_name }
    end

    trait :ineligible do
      cppc_case { false }
      extremism_separation { false }
      high_risk_of_serious_harm { false }
      mappa_level_2 { false }
      pathfinder_process { false }
      other_reason { false }
      stage2_validation { true }
    end

    trait :unsent do
      created_within_referral_window { false }
    end

    trait :stage2 do
      stage2_validation do
        true
      end
      extremism_separation do
        false
      end
      high_risk_of_serious_harm do false end
      mappa_level_2 do false end
      pathfinder_process do false end
      other_reason { false }
    end

    trait :unsent do
      created_within_referral_window { false }
    end
  end
end
