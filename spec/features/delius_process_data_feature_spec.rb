# frozen_string_literal: true

require 'rails_helper'

feature 'delius import scenarios', :disable_push_to_delius do
  let(:ldu) {  create(:local_delivery_unit) }
  let(:test_strategy) { Flipflop::FeatureSet.current.test! }
  let(:prison_code) { create(:prison).code }

  before do
    test_strategy.switch!(:auto_delius_import, true)
  end

  after do
    test_strategy.switch!(:auto_delius_import, false)
  end

  before do
    signin_spo_user([prison_code])
    stub_auth_token
    stub_user(staff_id: 123456)
  end

  context 'when one delius record' do
    let(:offender_no) { 'G4281GV' }
    let(:crn) { 'X45786587' }

    context 'with all data' do
      before do
        stub_community_offender(offender_no,
                                build(:community_data,
                                      otherIds: { crn: crn },
                                      offenderManagers: [build(:community_offender_manager,
                                                               team: { code: 'XYX', localDeliveryUnit: { code: ldu.code } })]))

        stub_offender(build(:nomis_offender, agencyId: prison_code, offenderNo: offender_no))
      end

      before do
        ProcessDeliusDataJob.perform_now offender_no
      end

      it 'displays without error messages' do
        visit prison_case_information_path(prison_code, offender_no)
        expect(page).not_to have_css('.govuk-error-summary')
        within '#offender_crn' do
          expect(page).to have_content crn
        end
      end
    end

    context 'without tier' do
      let(:offender_no) { 'G2911GD' }
      let(:offender) { build(:nomis_offender, agencyId: prison_code, offenderNo: offender_no) }

      before do
        stub_community_offender(offender_no, build(:community_data,
                                                   currentTier: 'XX',
                                                   offenderManagers: [build(:community_offender_manager,
                                                                            team: { code: 'XYX', localDeliveryUnit: { code: ldu.code } })]))

        stub_offenders_for_prison(prison_code, [offender])
      end

      before do
        ProcessDeliusDataJob.perform_now offender_no
      end

      it 'displays the correct error message' do
        visit missing_information_prison_prisoners_path(prison_code)
        within "#edit_#{offender_no}" do
          click_link 'Update'
        end

        within '.govuk-error-summary' do
          expect(page).to have_content 'no tiering calculation found'
        end
      end
    end
  end
end
