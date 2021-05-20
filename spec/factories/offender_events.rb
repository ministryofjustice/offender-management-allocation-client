FactoryBot.define do
  factory :offender_event do
    # needs to be populated by the consumer
    nomis_offender_id { nil }

    # needs to be populated by the consumer
    event { nil }

    happened_at { Time.zone.now }

    triggered_by { 'user' }
    triggered_by_nomis_username { 'MOIC' }

    # a Hash of metadata fields to store alongside the event (optional)
    metadata { nil }
  end
end
