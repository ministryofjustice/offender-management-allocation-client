FactoryBot.define do
  factory :movement, class: 'HmppsApi::Movement' do
    initialize_with do
      HmppsApi::Movement.from_json(attributes.stringify_keys)
    end

    trait :rotl do
      movementType { 'TAP' }
      directionCode  { 'OUT' }
    end

    trait :transfer do
      directionCode { 'IN' }
      movementType { 'TRN' }
    end

    trait :out do
      directionCode { 'OUT' }
      toAgency { MovementService::RELEASE_MOVEMENT_CODE }
      movementType { 'REL' }
    end

    fromAgency do
      'LEI'
    end

    # This should be far enough in the past so that the offender isn't considered a 'new arrival' by default
    sequence(:movementDate) do |seq|
      (Time.zone.today - 1.year - seq.days).to_s
    end

    toAgency do
      'SWI'
    end

    # default movement is 'in' (IN/ADM)
    directionCode { 'IN' }
    movementType { 'ADM' }
  end
end
