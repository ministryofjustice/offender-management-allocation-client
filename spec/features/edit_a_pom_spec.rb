# frozen_string_literal: true

require "rails_helper"

feature "edit a POM's details" do
  let!(:prison) { create(:prison) }

  context 'with VCR' do
    let(:nomis_staff_id) { 485_637 }
    let(:fulltime_pom_id) { 485_833 }
    let(:nomis_offender_id) { 'G4273GI' }
    let(:pom) { build(:pom) }

    before do
      create(:case_information, offender: build(:offender, nomis_offender_id: nomis_offender_id))

      create(:pom_detail, prison_code: 'LEI', nomis_staff_id: fulltime_pom_id, working_pattern: 1)

      signin_spo_user
    end

    it "setting unavailable shows selected on re-edit", vcr: { cassette_name: 'prison_api/edit_poms_unavailable_check' } do
      visit edit_prison_pom_path('LEI', nomis_staff_id)
      expect(page).to have_css('h1', text: 'Edit profile')

      choose('working_pattern-2')
      choose('Active but unavailable for new cases')
      click_on('Save')

      visit edit_prison_pom_path('LEI', nomis_staff_id)
      expect(page).to have_css('h1', text: 'Edit profile')

      expect(page).to have_field('status-conditional-unavailable', checked: true)
    end

    it "validates a POM when missing data", vcr: { cassette_name: 'prison_api/edit_poms_missing_check' } do
      visit edit_prison_pom_path('LEI', fulltime_pom_id)
      expect(page).to have_css('h1', text: 'Edit profile')

      expect(page.find('#working_pattern-ft')).to be_checked

      # The only way to trigger (and therefore cover) the validation is for a full-time POM
      # to be edited to part time but not choose a working pattern.
      choose('part-time-conditional-1')
      click_on('Save')

      expect(page).to have_css('h1', text: 'Edit profile')
      expect(page).to have_content('Select number of days worked')
    end

    describe "making an inactive POM active", :js, vcr: { cassette_name: 'prison_api/edit_poms_activate_pom_feature' } do
      let(:prison) { Prison.find('LEI') }
      let(:other_prison) { create(:prison) }
      let(:moic_integration_tests_staff_id) { 485_758 }

      before do
        # create 2 inactive POM details records (to make POM inactive) - there was a bug that found the first(and wrong) one
        create(:pom_detail, :inactive, prison: other_prison, nomis_staff_id: moic_integration_tests_staff_id)
        create(:pom_detail, :inactive, prison: prison, nomis_staff_id: moic_integration_tests_staff_id)
      end

      it 'makes the pom have a status of active' do
        visit "/prisons/LEI/poms"
        click_link "Inactive staff (1)"
        click_link 'Moic Integration-Tests'

        within first('.govuk-summary-list__row') do
          click_link "Change"
        end

        expect(page).to have_css('h1', text: 'Edit profile')

        find('label[for=status-active]').click
        find('label[for=part-time-conditional-1]').click
        find('label[for=working_pattern-5]').click

        click_button('Save')

        expect(prison.pom_details.find_by(nomis_staff_id: moic_integration_tests_staff_id).status).to eq('active')
        expect(other_prison.pom_details.find_by(nomis_staff_id: moic_integration_tests_staff_id).status).to eq('inactive')

        expect(page).to have_content('0.5')
        expect(page).to have_content('Active')
      end
    end

    context 'when a POM is made inactive' do
      before do
        # create an allocation with the POM as the primary POM
        create(
          :allocation_history,
          nomis_offender_id: 'G7806VO',
          primary_pom_nomis_id: 485_926,
          prison: 'LEI'
        )

        # create an allocation with the POM as the co-working POM
        create(
          :allocation_history,
          nomis_offender_id: 'G1670VU',
          primary_pom_nomis_id: 485_833,
          secondary_pom_nomis_id: 485_926,
          prison: 'LEI'
        )
      end

      it "de-allocates all a POM's cases", vcr: { cassette_name: 'prison_api/edit_poms_deactivate_pom_feature' } do
        visit "/prisons/LEI/poms/485926"
        within first('.govuk-summary-list__row') do
          click_link "Change"
        end

        expect(page).to have_content("Moic Pom")
        expect(AllocationHistory.count).to eq 2

        choose('working_pattern-2')
        choose('Inactive')
        click_button('Save')

        expect(page).to have_content("Moic Pom")
        expect(page).to have_css('.offender_row_0', count: 0)
      end
    end
  end

  context 'without VCR' do
    let!(:pom_detail) { create(:pom_detail, prison: prison) }

    before do
      stub_auth_token
      stub_offenders_for_prison(prison.code, [])
      stub_poms(prison.code, [build(:pom, staffId: pom_detail.nomis_staff_id)])

      signin_spo_user([prison.code])
    end

    it 'returns you to to the pom work load page' do
      visit prison_pom_path(prison.code, pom_detail.nomis_staff_id)
      within first('.govuk-summary-list__row') do
        click_link "Change"
      end
      click_link "Cancel"
      expect(page).to have_current_path(prison_pom_path(prison.code, pom_detail.nomis_staff_id))
    end
  end
end
