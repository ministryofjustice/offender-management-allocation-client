# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "poms/show", type: :view do
  let(:page) { Nokogiri::HTML(rendered) }
  let(:prison) { create(:prison) }
  let(:pom) { build(:pom) }
  let(:offender_nos) { offenders.map(&:offender_no) }
  let(:summary_rows) { page.css('.govuk-summary-list__row') }
  let(:two_days_ago) { Time.zone.today - 2.days }

  before do
    stub_auth_token
    stub_poms prison.code, [pom]

    assign :prison, prison
    assign :pom, StaffMember.new(prison, pom.staff_id)
    assign :tab, tabname

    assign(:allocations, offenders.zip(allocations).map { |offender, allocation|
      AllocatedOffender.new(pom.staff_id,
                            allocation,
                            offender)
    })

    render
  end

  context 'when on the overview tab' do
    let!(:allocations) {
      [
        create(:allocation_history, prison: prison.code, nomis_offender_id: offender_nos.first,
               primary_pom_nomis_id: pom.staff_id, primary_pom_allocated_at: Time.zone.today - 3.days),
      # Yes this line doesn't make sense. But the code cannot (easily/at all) work out the allocation date for co-working - so let's not try that hard until allocation data is fixed
        create(:allocation_history, prison: prison.code, nomis_offender_id: offender_nos.second,
               secondary_pom_nomis_id: pom.staff_id, primary_pom_allocated_at: two_days_ago),

        create(:allocation_history, prison: prison.code, nomis_offender_id: offender_nos.third,
               primary_pom_nomis_id: pom.staff_id,
               updated_at: Time.zone.today - 8.days, primary_pom_allocated_at: Time.zone.today - 8.days),

      # add an allocation for an indeterminate with no release date
        create(:allocation_history, prison: prison.code, nomis_offender_id: offender_nos.fourth,
               primary_pom_nomis_id: pom.staff_id,
               updated_at: Time.zone.today - 8.days, primary_pom_allocated_at: Time.zone.today - 8.days)
      ]
    }
    let(:api_one) { build(:hmpps_api_offender, sentence: build(:sentence_detail, releaseDate: Time.zone.today + 2.weeks)) }
    let(:api_two) { build(:hmpps_api_offender, sentence: build(:sentence_detail, releaseDate: Time.zone.today + 5.weeks)) }
    let(:api_three) { build(:hmpps_api_offender, sentence: build(:sentence_detail, releaseDate: Time.zone.today + 8.weeks)) }
    let(:api_four) { build(:hmpps_api_offender, sentence: build(:sentence_detail, :indeterminate)) }
    let(:offenders) {
      [api_one, api_two, api_three, api_four].map { |api_offender|
        build(:mpc_offender, prison_record: api_offender, offender: build(:case_information).offender, prison: prison)
      }
    }
    let(:tabname) { 'overview' }

    it 'shows working pattern' do
      expect(summary_rows.first).to have_content('Working pattern')
    end

    it 'shows last case allocated date' do
      expect(summary_rows[2]).to have_content(two_days_ago.to_s(:rfc822))
    end

    it 'shows allocations in last 7 days' do
      expect(summary_rows[3]).to have_content(2)
    end

    it 'shows releases due in next 4 weeks' do
      expect(summary_rows[4]).to have_content(1)
    end
  end

  context 'when on the caseload tab' do
    let(:case_info) { create(:case_information) }
    let(:api_offender) { build(:hmpps_api_offender, offenderNo: case_info.nomis_offender_id) }
    let(:offender) { build(:mpc_offender, prison_record: api_offender, offender: case_info.offender, prison: prison) }
    let(:allocations) { [build(:allocation_history, nomis_offender_id: case_info.nomis_offender_id)] }

    let(:first_offender_row) {
      row = page.css('td').map(&:text).map(&:strip)
      # The first column is offender name and number underneath each other - just grab the non-blank data
      split_col_zero = row.first.split("\n").map(&:strip).reject(&:empty?)
      [split_col_zero] + row[1..]
    }
    let(:tabname) { 'caseload' }
    let(:offenders) { [offender] }

    it 'displays correct headers' do
      expect(page.css('th a').map(&:text).map(&:strip)).to eq(["Case", "Location", "Tier", "Earliest release date", "Allocationdate", "Role"])
    end

    it 'displays correct data' do
      expect(first_offender_row).
        to eq [
                [offender.full_name, case_info.nomis_offender_id],
                "N/A",
                case_info.tier,
                offender.earliest_release_date.to_s(:rfc822),
                Time.zone.today.to_s(:rfc822),
                "Co-working"
              ]
    end
  end
end
