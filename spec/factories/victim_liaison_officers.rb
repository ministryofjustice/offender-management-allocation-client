FactoryBot.define do
  factory :victim_liaison_officer do
    association :offender

    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.email }
  end
end
