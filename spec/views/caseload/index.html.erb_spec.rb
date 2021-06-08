# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "caseload/index", type: :view do
  before do
    assign(:pending_task_count, 0)
    assign(:allocations,
           Kaminari::paginate_array(offenders).page(1))
    assign(:new_cases_count, 0)
    assign(:pending_handover_count, offenders.count)
    assign(:pom, StaffMember.new(prison, staff_id))
    assign(:prison, prison)
    assign(:staff_id, staff_id)
  end

  let(:staff_id) { build(:pom).staff_id }
  let(:page) { Nokogiri::HTML(rendered) }

  context 'with a caseload' do
    let(:offenders) {
      build_list(:hmpps_api_offender, 1).map do |o|
        AllocatedOffender.new(staff_id, build(:allocation_history, nomis_offender_id: o.offender_no), o)
      end
    }

    context 'with a male prison' do
      before do
        render
      end

      let(:prison) { create(:prison) }

      it 'displays caseload' do
        expect(page).to have_content 'Your caseload'
      end

      it 'displays correct headers' do
        expect(page.css('th a').map(&:text).map(&:strip)).to eq(["Prisoner name", "Location", "Tier", "Earliest release date", "Allocationdate", "Role"])
      end
    end

    context 'with a female prison' do
      let(:prison) { create(:womens_prison) }

      before do
        render
      end

      it 'displays caseload' do
        expect(page).to have_content 'Your caseload'
        expect(page).to have_content 'Medium'
      end

      it 'displays correct headers' do
        expect(page.css('th a').map(&:text).map(&:strip)).to eq(["Prisoner name", "Location", "Tier", "Complexity level", "Earliest release date", "Role"])
      end
    end
  end

  context 'with no caseload' do
    before do
      render
    end

    let(:offenders) { [] }
    let(:prison) { create(:prison) }

    it 'displays an empty page' do
      expect(page).to have_content 'No allocated cases'
    end
  end
end
