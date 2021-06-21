require 'rails_helper'

RSpec.describe "prisoners/show", type: :view do
  describe 'early allocation badges' do
    let(:prison) { create(:prison) }
    let(:page) { Nokogiri::HTML(rendered) }
    let(:early_allocation_css) { page.css('#early-allocation-badge') }
    let(:early_allocation_badge) { early_allocation_css.first }
    let(:badge_count) { early_allocation_css.size }
    let(:api_offender) { build(:hmpps_api_offender, sentence: sentence) }
    let(:offender) { build(:mpc_offender, prison: prison, offender: case_info.offender, prison_record: api_offender) }

    before do
      assign(:prison, prison)
      assign(:prisoner, offender)
      assign(:tasks, [])
      assign(:keyworker, build(:keyworker))
      render
    end

    context 'with early allocation' do
      let(:case_info) { create(:case_information, offender: build(:offender, early_allocations: [early_allocation])) }

      context 'when unsent' do
        let(:early_allocation) { build(:early_allocation, :pre_window) }
        let(:sentence) { build(:sentence_detail, :outside_early_allocation_window) }

        it 'displays a badge text EARLY ALLOCATION NOTES' do
          expect(badge_count).to eq(1)
          expect(early_allocation_badge.attributes['class'].value).to include 'moj-badge--blue'
          expect(early_allocation_badge.text.strip).to eq 'EARLY ALLOCATION ASSESSMENT SAVED'
        end
      end

      context 'when submitted' do
        # default sentence is inside EA 18 month window
        let(:sentence) { build(:sentence_detail) }

        context 'when rejected' do
          let(:early_allocation) { build(:early_allocation, :discretionary_declined) }

          it 'displays badge text EARLY ALLOCATION NOTES' do
            expect(badge_count).to eq(1)
            expect(early_allocation_badge.attributes['class'].value).to include 'moj-badge--blue'
            expect(early_allocation_badge.text.strip).to eq 'EARLY ALLOCATION ASSESSMENT SAVED'
          end
        end

        context 'when it is awaiting review by NSD/LDU' do
          let(:early_allocation) { build(:early_allocation, :discretionary) }

          it 'displays badge text EARLY ALLOCATION ACTIVE' do
            expect(badge_count).to eq(1)
            expect(early_allocation_badge.attributes['class'].value).to include 'moj-badge--blue'
            expect(early_allocation_badge.text.strip).to eq 'EARLY ALLOCATION DECISION PENDING'
          end
        end

        context 'when it has been approved by NSD/LDU' do
          let(:early_allocation) { build(:early_allocation, :discretionary_accepted) }

          it 'displays badge text EARLY ALLOCATION APPROVED' do
            expect(badge_count).to eq(1)
            expect(early_allocation_badge.attributes['class'].value).to include 'moj-badge--blue'
            expect(early_allocation_badge.text.strip).to eq 'EARLY ALLOCATION ELIGIBLE'
          end
        end

        context 'when it is automatic' do
          let(:early_allocation) { build(:early_allocation, :eligible) }

          it 'displays badge text EARLY ALLOCATION APPROVED' do
            expect(early_allocation_badge.attributes['class'].value).to include 'moj-badge--blue'
            expect(early_allocation_badge.text.strip).to eq 'EARLY ALLOCATION ELIGIBLE'
          end
        end
      end
    end

    context 'without an early allocation' do
      let(:case_info) { build(:case_information) }
      let(:sentence) { build(:sentence_detail) }

      it 'has no badge' do
        expect(early_allocation_badge).to be_nil
      end
    end
  end
end
