require 'rails_helper'

describe SummaryService do
  # TODO: - Populate test db with Case Information
  it "will generate a summary", vcr: { cassette_name: :allocation_summary_service_summary } do
    summary = described_class.summary(:pending, 'LEI', 15, SummaryService::SummaryParams.new)

    expect(summary.offenders.count).to eq(20)
    expect(summary.page_count).to eq(42)
  end

  it "will sort a summary", vcr: { cassette_name: :allocation_summary_service_summary_sort } do
    asc_summary = described_class.summary(
      :pending,
      'LEI',
      1,
      SummaryService::SummaryParams.new(sort_field: :last_name)
    )
    asc_cells = asc_summary.offenders.map(&:offender_no)

    desc_summary = described_class.summary(
      :pending,
      'LEI',
      1,
      SummaryService::SummaryParams.new(sort_direction: :desc, sort_field: :last_name)
    )
    desc_cells = desc_summary.offenders.map(&:offender_no)

    expect(asc_cells).not_to match_array(desc_cells)
  end

  describe 'entered_prison_dates' do
    asc_summary = described_class.summary(
      :pending,
      'LEI',
      1,
      SummaryService::SummaryParams.new(sort_field: :last_name)
    )

    it 'gets the prison dates for list of offenders', vcr: { cassette_name: :allocation_summary_service_entered_prison_dates } do
      prison_dates = described_class.entered_prison_dates(asc_summary.offenders)
      expect(prison_dates).to be_an(Array)
      expect(prison_dates.first).to include(:offender_no, :days_count)
    end

    it 'returns nil if there are no offenders', vcr: { cassette_name: :allocation_summary_service_entered_prison_dates_blank } do
      prison_dates = described_class.entered_prison_dates([])
      expect(prison_dates).to be(nil)
    end
  end
end
