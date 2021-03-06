# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AllocationStaffController, type: :controller do
  let(:poms) {
    [
      build(:pom, :prison_officer, emails: []),
      build(:pom, :prison_officer),
      build(:pom, :probation_officer),
      build(:pom, :probation_officer)
    ]
  }
  let(:pom_without_emails) { poms.first }
  let(:prison_code) { create(:prison).code }
  let(:offender) { build(:nomis_offender, agencyId: prison_code) }
  let(:offender_no) { offender.fetch(:offenderNo) }

  before do
    stub_poms(prison_code, poms)
    stub_offender(offender)
    stub_movements_for offender_no, [attributes_for(:movement)]
  end

  context 'when user is an SPO' do
    before do
      stub_sso_data(prison_code)
    end

    describe '#index' do
      let(:alice) { poms.first }

      context 'with an allocation from a previous prison' do
        before do
          create(:case_information, offender: build(:offender, nomis_offender_id: offender_no))
          create(:allocation_history, prison: build(:prison).code, nomis_offender_id: offender_no)
        end

        it 'makes a nil current POM' do
          get :index, params: { prison_id: prison_code, prisoner_id: offender_no }
          expect(response).to be_successful
          expect(assigns(:current_pom)).to be_nil
        end
      end

      context 'with previous allocations for this POM' do
        before do
          { a: 5, b: 4, c: 3, d: 2 }.each do |tier, quantity|
            0.upto(quantity - 1) do
              info = create(:case_information, tier: tier.to_s.upcase)
              create(:allocation_history, prison: prison_code, nomis_offender_id: info.nomis_offender_id, primary_pom_nomis_id: alice.staffId)
            end
          end
          info = create(:case_information, tier: 'N/A')
          create(:allocation_history, prison: prison_code, nomis_offender_id: info.nomis_offender_id, primary_pom_nomis_id: alice.staffId)

          offenders = CaseInformation.all.map { |ci| build(:nomis_offender, offenderNo: ci.nomis_offender_id) }
          stub_offenders_for_prison(prison_code, offenders, [attributes_for(:movement)])

          create(:case_information, offender: build(:offender, nomis_offender_id: offender_no), tier: tier)
          get :index, params: { prison_id: prison_code, prisoner_id: offender_no }
          expect(response).to be_successful
        end

        context 'when tier D' do
          let(:tier) { 'D' }

          render_views

          it 'serves correct counts' do
            pom = assigns(:prison_poms).detect { |c| c.first_name == alice.firstName }

            expect(tier_a: pom.allocations.count { |a| a.tier == 'A' },
                   tier_b: pom.allocations.count { |a| a.tier == 'B' },
                   tier_c: pom.allocations.count { |a| a.tier == 'C' },
                   tier_d: pom.allocations.count { |a| a.tier == 'D' },
                   no_tier: pom.allocations.count { |a| a.tier == 'N/A' },
                   total_cases: pom.allocations.count)
              .to eq(tier_a: 5, tier_b: 4, tier_c: 3, tier_d: 2, no_tier: 1, total_cases: 15)
          end

          it 'has a nil allocation' do
            expect(assigns(:allocation)).to be_nil
            expect(response.body).to have_content 'No history'
          end

          it 'serves prison POMs' do
            expect(assigns(:prison_poms).map(&:first_name)).to match_array(poms.first(2).map(&:firstName))
          end
        end

        context 'when tier A' do
          let(:tier) { 'A' }

          it 'serves probation POMs' do
            expect(assigns(:probation_poms).map(&:first_name)).to match_array(poms.last(2).map(&:firstName))
          end
        end
      end

      context 'with an allocation' do
        before do
          stub_offenders_for_prison(prison_code, [offender])
          create(:case_information, offender: build(:offender, nomis_offender_id: offender_no))
          create(:allocation_history, prison: prison_code, nomis_offender_id: offender_no, primary_pom_nomis_id: poms.last.staff_id)
        end

        it 'sets allocation so that last_event can be displayed' do
          get :index, params: { prison_id: prison_code, prisoner_id: offender_no }
          expect(response).to be_successful
          expect(assigns(:allocation)).not_to be_nil
        end

        context 'when deallocated' do
          before do
            AllocationHistory.last.deallocate_offender_after_release
          end

          it 'retrives old POMs' do
            get :index, params: { prison_id: prison_code, prisoner_id: offender_no }
            expect(response).to be_successful
            expect(assigns(:previous_poms).map(&:staff_id)).to eq [poms.last.staff_id]
          end
        end
      end
    end
  end
end
