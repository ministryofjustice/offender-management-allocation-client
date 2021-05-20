FactoryBot.define do
  factory :new_allocation do
    association :case_information
    association :pom_detail, prison_code: 'LEI'
    allocation_type { 'primary' }

    trait :primary do
      allocation_type { 'primary' }
    end

    trait :coworking do
      allocation_type { 'coworking' }
    end
  end
end
