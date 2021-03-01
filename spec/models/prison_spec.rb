require 'rails_helper'

RSpec.describe Prison, type: :model do
  describe '#active' do
    before do
      create(:allocation, prison: p1.code)
      create(:allocation, prison: p1.code)
      create(:allocation, prison: p2.code)
    end

    let(:p1) { build(:prison) }
    let(:p2) { build(:prison) }

    it 'only lists prisons with allocations' do
      expect(described_class.active.map(&:code)).to match_array [p1, p2].map(&:code)
    end
  end

  describe '#offenders' do
    subject { described_class.new("LEI").offenders }

    it "get first page of offenders for a specific prison",
       vcr: { cassette_name: :offender_service_offenders_by_prison_first_page_spec } do
      offender_array = subject.first(9)
      expect(offender_array).to be_kind_of(Array)
      expect(offender_array.length).to eq(9)
      expect(offender_array.first).to be_kind_of(HmppsApi::OffenderSummary)
    end

    it "get last page of offenders for a specific prison", vcr: { cassette_name: :offender_service_offenders_by_prison_last_page_spec } do
      offender_array = subject.to_a
      expect(offender_array).to be_kind_of(Array)
      expect(offender_array.length).to be > 800
      expect(offender_array.first).to be_kind_of(HmppsApi::OffenderSummary)
    end

    context 'when recall flag set' do
      let(:offenders) { build_list(:nomis_offender, 2, recall: true) }

      before do
        stub_auth_token
        stub_offenders_for_prison('LEI', offenders)
      end

      it 'populates the recall flag' do
        expect(subject.map(&:recalled?)).to eq [true, true]
      end
    end

    context 'when the search API misses someone' do
      let(:offenders) { [build(:nomis_offender, recall: true), build(:nomis_offender, recall: false), build(:nomis_offender, recall: true)] }
      let(:offender_nos) { offenders.map { |o| o.fetch(:offenderNo) } }

      before do
        stub_auth_token
        stub_request(:get, "#{ApiHelper::T3}/locations/description/LEI/inmates?convictedStatus=Convicted&returnCategory=true").
          with(
            headers: {
              'Page-Limit' => Prison::OffenderEnumerator::FETCH_SIZE.to_s,
              'Page-Offset' => '0',
            }).
          to_return(body: offenders.to_json)

        stub_request(:post, "#{ApiHelper::T3_SEARCH}/prisoner-numbers").
          with(
            body: { prisonerNumbers: offender_nos }.to_json
          ).
          to_return(body: offenders.first(2).map { |o|
            { prisonerNumber: o.fetch(:offenderNo),
              recall: o.fetch(:recall) }
          }                          .to_json)

        stub_request(:post, "#{ApiHelper::T3}/movements/offenders?latestOnly=true&movementTypes=TAP").
          with(body: offender_nos.to_json).
          to_return(body: [].to_json)

        bookings = offenders.map { |offender| { 'bookingId' => offender.fetch(:bookingId), 'sentenceDetail' => offender.fetch(:sentence) } }
        stub_request(:post, "#{ApiHelper::T3}/offender-sentences/bookings").
          with(body: offenders.map { |o| o.fetch(:bookingId) }.to_json).
          to_return(body: bookings.to_json)

        stub_request(:post, "#{ApiHelper::T3}/movements/offenders?latestOnly=false&movementTypes=TRN").
            with(
              body: offenders.map { |o| o.fetch(:offenderNo) }.to_json,
            ).
            to_return(body: [].to_json)
      end

      it 'returns falses when missing' do
        expect(subject.map(&:recalled?)).to eq([true, false, false])
      end
    end

    context 'when there are exactly FETCH_SIZE offenders' do
      let(:offenders) { build_list(:nomis_offender, Prison::OffenderEnumerator::FETCH_SIZE) }
      let(:offender_nos) { offenders.map { |o| o.fetch(:offenderNo) } }

      before do
        stub_auth_token
        stub_request(:get, "#{ApiHelper::T3}/locations/description/LEI/inmates?convictedStatus=Convicted&returnCategory=true").
          with(
            headers: {
              'Page-Limit' => Prison::OffenderEnumerator::FETCH_SIZE.to_s,
              'Page-Offset' => '0',
            }).
          to_return(body: offenders.to_json)

        stub_request(:post, "#{ApiHelper::T3_SEARCH}/prisoner-numbers").
          with(
            body: { prisonerNumbers: offender_nos }.to_json
          ).
          to_return(body: offenders.map { |o|
                            { prisonerNumber: o.fetch(:offenderNo),
                                                recall: o.fetch(:recall) }
                          }                          .to_json)

        stub_request(:post, "#{ApiHelper::T3}/movements/offenders?latestOnly=true&movementTypes=TAP").
          with(body: offender_nos.to_json).
          to_return(body: [].to_json)

        bookings = offenders.map { |offender| { 'bookingId' => offender.fetch(:bookingId), 'sentenceDetail' => offender.fetch(:sentence) } }
        stub_request(:post, "#{ApiHelper::T3}/offender-sentences/bookings").
          with(body: offenders.map { |o| o.fetch(:bookingId) }.to_json).
          to_return(body: bookings.to_json)

        stub_request(:post, "#{ApiHelper::T3}/movements/offenders?latestOnly=false&movementTypes=TRN").
            with(
              body: offenders.map { |o| o.fetch(:offenderNo) }.to_json,
                ).
            to_return(body: [].to_json)
      end

      it 'fetches one page only' do
        expect(subject.count).to eq(Prison::OffenderEnumerator::FETCH_SIZE)
      end
    end
  end
end
