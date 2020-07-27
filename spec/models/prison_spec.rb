require 'rails_helper'

RSpec.describe Prison, type: :model do
  describe '#offenders' do
    let(:offenders) { described_class.new("LEI").offenders }

    it "get first page of offenders for a specific prison",
       vcr: { cassette_name: :offender_service_offenders_by_prison_first_page_spec } do
      offender_array = offenders.first(9)
      expect(offender_array).to be_kind_of(Array)
      expect(offender_array.length).to eq(9)
      expect(offender_array.first).to be_kind_of(Nomis::OffenderSummary)
    end

    it "get last page of offenders for a specific prison", vcr: { cassette_name: :offender_service_offenders_by_prison_last_page_spec } do
      offender_array = offenders.to_a
      expect(offender_array).to be_kind_of(Array)
      expect(offender_array.length).to be > 750
      expect(offender_array.first).to be_kind_of(Nomis::OffenderSummary)
    end
  end
end
