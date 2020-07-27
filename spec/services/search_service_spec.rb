require 'rails_helper'

describe SearchService do
  it "will return all of the records if no search", vcr: { cassette_name: :search_service_all } do
    offenders = described_class.search_for_offenders('', Prison.new('LEI'))
    expect(offenders.count).to be > 770
  end

  it "will return a filtered list if there is a search", vcr: { cassette_name: :search_service_filtered } do
    offenders = described_class.search_for_offenders('Cal', Prison.new('LEI'))
    expect(offenders.count).to eq(5)
  end

  it "will handle a nil search term", vcr: { cassette_name: :search_service_no_term } do
    offenders = described_class.search_for_offenders(nil, Prison.new('LEI'))
    expect(offenders.count).to eq(0)
  end
end
