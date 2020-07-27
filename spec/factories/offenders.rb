FactoryBot.define do
  class Elite2Booking
    attr_reader :sentenceDetail

    # rubocop:disable Naming/VariableName
    def initialize(data)
      @sentenceDetail = data[:sentenceDetail]
    end
    # rubocop:enable Naming/VariableName
  end

  factory :offender, class: 'Nomis::Offender' do
    initialize_with { Nomis::Offender.from_json(attributes.stringify_keys) }

    imprisonmentStatus { 'SENT03' }
    prisonId { 'LEI' }

    # offender numbers are of the form <letter><4 numbers><2 letters>
    sequence(:offenderNo) do |seq|
      number = seq / 26 + 1000
      letter = ('A'..'Z').to_a[seq % 26]
      # This and case_information should produce different values to avoid clashes
      "T#{number}O#{letter}"
    end
    sequence(:bookingId) { |x| x + 700_000 }
    convictedStatus { 'Convicted' }
    dateOfBirth { Date.new(1990, 12, 6).to_s }
    firstName { Faker::Name.first_name }
    # We have some issues with corrupting the display
    # of names containing Mc or Du :-(
    # also ensure uniqueness as duplicate last names can cause issues
    # in tests, as ruby sort isn't stable by default
    sequence(:lastName) { |c| "#{Faker::Name.last_name.titleize}_#{c}" }
    categoryCode { 'C' }
  end

  factory :booking, class: 'Elite2Booking' do
    initialize_with do new(attributes) end

    sequence(:sentenceDetail) { |seq|
      {
        'tariffDate' => Date.new(2032 + seq % 5, 3, 17) - (seq * 2).days,
        'sentenceStartDate' => Date.new(2009, 2, 8),
        'conditionalReleaseDate' => Date.new(2032 + seq % 5, 3, 17) - (seq * 2).days
      }
    }
  end
end
