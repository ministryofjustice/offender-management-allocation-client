# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "allocations/index", type: :view do
  let(:page) { Nokogiri::HTML(rendered) }
  let(:offender) { build(:offender) }

  before do
    assign(:prison, create(:prison))
    assign(:prisoner, offender)
    assign(:previously_allocated_pom_ids, [])
    assign(:recommended_poms, [])
    assign(:not_recommended_poms, [])
    assign(:unavailable_pom_count, 0)
    assign(:case_info, build(:case_information))
    render
  end

  it 'shows handover dates' do
    expect(page.css('#handover-start-date-row')).to have_text('Handover start date')
    expect(page.css('#handover-start-date-row')).to have_text('05/11/2021')

    expect(page.css('#responsibility-handover-date-row')).to have_text('Responsibility handover')
    expect(page.css('#responsibility-handover-date-row')).to have_text('05/11/2021')
  end

  describe 'category label' do
    let(:key) { page.css('#offender-category > td:nth-child(1)').text }
    let(:value) { page.css('#offender-category > td:nth-child(2)').text }

    context 'when a male offender category' do
      let(:offender) { build(:offender, category: build(:offender_category, :cat_d)) }

      it 'shows the category label' do
        expect(key).to eq('Category')
        expect(value).to eq('Cat D')
      end
    end

    context 'when a female offender category' do
      let(:offender) { build(:offender, category: build(:offender_category, :female_open)) }

      it 'shows the category label' do
        expect(key).to eq('Category')
        expect(value).to eq('Female Open')
      end
    end

    context 'when category is unknown' do
      # This happens when an offender's category assessment hasn't been completed yet
      let(:offender) { build(:offender, category: nil) }

      it 'shows "Unknown"' do
        expect(key).to eq('Category')
        expect(value).to eq('Unknown')
      end
    end
  end
end
