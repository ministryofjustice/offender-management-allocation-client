require 'rails_helper'

feature 'complexity level feature' do
  let(:offender) { build(:nomis_offender, complexityLevel: 'high', agencyId: womens_prison.code, firstName: 'Sally', lastName: 'Albright') }
  let(:womens_prison) { create(:womens_prison) }
  let(:offenders) { [offender] }
  let(:pom) { build(:pom) }
  let(:spo) { build(:pom) }
  let(:offender_no) { offender.fetch(:offenderNo) }


  before do
    create(:allocation_history, nomis_offender_id: offender.fetch(:offenderNo), primary_pom_nomis_id: pom.staff_id,  prison: womens_prison.code)
    create(:case_information, offender: build(:offender, nomis_offender_id: offender.fetch(:offenderNo)))

    stub_offenders_for_prison(womens_prison.code, offenders)
    stub_signin_spo(spo, [womens_prison.code])
    stub_poms(womens_prison.code, [pom, spo])
    stub_keyworker(womens_prison.code, offender.fetch(:offenderNo), build(:keyworker))
  end

  context 'when on allocation information page' do
    it 'can update the complexity level journey' do
      expect(HmppsApi::ComplexityApi).to receive(:save).with(offender.fetch(:offenderNo), level: 'low', username: "MOIC_POM", reason: 'bla bla bla')

      # Journey starts on prisoner profile page. It should display the existing complexity level and a change link.
      visit prison_prisoner_allocation_path(prisoner_id: offender.fetch(:offenderNo), prison_id: womens_prison.code)

      expect(page).to have_text('Complexity of need level')
      expect(page).to have_css('#complexity-level', text: 'High')
      expect(page).to have_css('#complexity-badge', text: 'HIGH COMPLEXITY')

      within(:css, "td#complexity-level") do
        click_link('Change')
      end

      # Taken to the edit page to update the complexity level
      expect(page).to have_text 'Update complexity of need level'

      # The radio buttons should have the current complexity level checked
      high_radio_button = find('#complexity-level-high-field', visible: false)
      expect(high_radio_button).to be_checked

      # Updated level radio button checked
      find('label[for=complexity-level-low-field]').click
      # Text area left blank
      click_on('Update')
      # Shows errors
      expect(page).to have_css('.govuk-error-message')
      expect(page).to have_text('Enter the reason why the level has changed')

      # Happy path - Textarea Filled in and complexity updated from high to low
      find('textarea#complexity-reason-field-error', visible: false)
      fill_in id: 'complexity-reason-field-error', with: 'bla bla bla'
      click_on('Update')

      # Displays confirmation page
      expect(page).to have_css('#complexity-level-update', text: 'Low')

      # Change the API response to reflect the newly updated level
      stub_request(:get, "#{Rails.configuration.complexity_api_host}/v1/complexity-of-need/offender-no/#{offender_no}").
        to_return(body: { level: 'low' }.to_json)

      click_on('Return to prisoner page')

      expect(page).to have_current_path(prison_prisoner_allocation_path(prisoner_id: offender.fetch(:offenderNo), prison_id: womens_prison.code), ignore_query: true)
      expect(page).to have_css('#complexity-level', text: 'Low')
      expect(page).to have_css('#complexity-badge', text: 'LOW COMPLEXITY')
    end

    it 'can click back link to return to the prisoner profile page' do
      visit prison_prisoner_allocation_path(prisoner_id: offender.fetch(:offenderNo), prison_id: womens_prison.code)
      within(:css, "td#complexity-level") do
        click_link('Change')
      end

      # Taken to the edit page to update the complexity level
      expect(page).to have_text 'Update complexity of need level'

      click_link('Back')
      expect(page).to have_current_path(prison_prisoner_allocation_path(prisoner_id: offender.fetch(:offenderNo), prison_id: womens_prison.code))
    end
  end

  context 'when on the new allocation page' do
    context 'when changing the complexity level' do
      it 'can click back link to return to the new allocation page' do
        visit prison_prisoner_staff_index_path(womens_prison.code, offender_no)

        within(:css, "tr#complexity-level-row") do
          click_link('Change')
        end

        expect(page).to have_text 'Update complexity of need level'

        click_link('Back')
        expect(page).to have_current_path(prison_prisoner_staff_index_path(womens_prison.code, offender_no))
      end

      it 'can update the complexity level' do
        expect(HmppsApi::ComplexityApi).to receive(:save).with(offender.fetch(:offenderNo), level: 'low', username: "MOIC_POM", reason: 'bla bla bla')

        visit prison_prisoner_staff_index_path(womens_prison.code, offender_no)

        within(:css, "tr#complexity-level-row") do
          click_link('Change')
        end

        # The radio buttons should have the current complexity level checked
        high_radio_button = find('#complexity-level-high-field', visible: false)
        expect(high_radio_button).to be_checked

        # Updated level radio button checked
        find('label[for=complexity-level-low-field]').click
        # Text area left blank to demonstrate errors
        click_on('Update')

        # Shows errors
        expect(page).to have_css('.govuk-error-message')
        expect(page).to have_text('Enter the reason why the level has changed')

        # Happy path - Textarea Filled in and complexity updated from high to low
        fill_in('complexity[reason]', with: 'bla bla bla')

        # Change the API response to reflect the newly updated level
        stub_request(:get, "#{Rails.configuration.complexity_api_host}/v1/complexity-of-need/offender-no/#{offender_no}").
        to_return(body: { level: 'low' }.to_json)

        click_on('Update')

        expect(page).to have_current_path(prison_prisoner_staff_index_path(womens_prison.code, offender_no))
        expect(page).to have_css('#complexity-level-row', text: 'Low')
        expect(page).to have_css('#complexity-badge', text: 'LOW COMPLEXITY')
      end
    end
  end
end
