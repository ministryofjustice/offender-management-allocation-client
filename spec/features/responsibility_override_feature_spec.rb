require 'rails_helper'

feature 'Responsibility override' do
  include ActiveJob::TestHelper

  before do
    signin_spo_user
  end

  let(:offender_id) { 'G8060UF' }
  let(:pom_id) { 485_926 }

  context 'when overriding responsibility', :queueing, vcr: { cassette_name: :override_responsibility } do
    before do
      ldu = create(:local_divisional_unit, email_address: 'ldu@test.com')
      team = create(:team, local_divisional_unit: ldu)
      create(:case_information, nomis_offender_id: offender_id, team: team)
    end

    context 'with an allocation' do
      before do
        create(:allocation, primary_pom_nomis_id: pom_id, nomis_offender_id: offender_id)
      end

      it 'overrides' do
        visit prison_allocation_path('LEI', offender_id)

        within '.responsibility_change' do
          click_link 'Change'
        end

        expect(page).not_to have_css('govuk-textarea--error')
        click_button 'Continue'

        expect(page).to have_content 'Select a reason for overriding the responsibility'
        find('#reason_recall').click
        click_button 'Continue'

        expect {
          click_button 'Confirm'
        }.to change(enqueued_jobs, :count).by(2)

        expect(page).to have_content 'Current responsibility Community'
        expect(page).to have_current_path(prison_allocation_path('LEI', offender_id))
      end
    end

    context 'without allocation' do
      it 'overrides' do
        visit new_prison_allocation_path('LEI', offender_id)

        within '.responsibility_change' do
          click_link 'Change'
        end

        find('#reason_prob_team').click
        click_button 'Continue'

        expect {
          click_button 'Confirm'
        }.to change(enqueued_jobs, :count).by(2)

        expect(page).to have_current_path(new_prison_allocation_path('LEI', offender_id))
        expect(page).to have_content 'Current case owner Community'
      end

      it 'shows the correct POM recommendations' do
        override_responsibility_for(offender_id)

        visit new_prison_allocation_path('LEI', offender_id)
        expect(page).to have_content 'Recommendation: Prison officer POM'
      end

      it 'shows case owner as Community when overridden' do
        override_responsibility_for(offender_id)

        visit prison_summary_unallocated_path('LEI')

        within 'tr.govuk-table__row.offender_row_0' do
          expect(page).to have_content('Community')
        end
      end
    end
  end

  context "when override isn't possible due to email address is nil", vcr: { cassette_name: :cant_override_responsibility_nil_email } do
    before do
      ldu = create(:local_divisional_unit, email_address: nil)
      team = create(:team, local_divisional_unit: ldu)
      create(:case_information, nomis_offender_id: offender_id, team: team)
    end

    it 'doesnt override' do
      visit new_prison_allocation_path('LEI', offender_id)

      within '.responsibility_change' do
        click_link 'Change'
      end

      expect(page).to have_content "Responsibility for this case can't be changed"
    end
  end

  context "when override isn't possible due to email address is an empty string", vcr: { cassette_name: :cant_override_responsibility_blank_email } do
    before do
      ldu = create(:local_divisional_unit, email_address: "")
      team = create(:team, local_divisional_unit: ldu)
      create(:case_information, nomis_offender_id: offender_id, team: team)
    end

    it 'doesnt allow an override to take place' do
      visit new_prison_allocation_path('LEI', offender_id)

      within '.responsibility_change' do
        click_link 'Change'
      end

      expect(page).to have_content "Responsibility for this case can't be changed"
    end
  end

  def override_responsibility_for(offender_id)
    visit new_prison_allocation_path('LEI', offender_id)

    within '.responsibility_change' do
      click_link 'Change'
    end

    find('#reason_prob_team').click
    click_button 'Continue'
    click_button 'Confirm'
  end
end
