require 'rails_helper'

feature 'Co-working' do
  let!(:nomis_offender_id) { 'G4273GI' }
  let!(:prison_pom) do
    {
      staff_id: 485_926,
      pom_name: 'Moic Pom',
      email: 'pom@digital.justice.gov.uk'
    }
  end

  let!(:secondary_pom) do
    {
      staff_id: 485_758,
      pom_name: 'Moic Integration-Tests',
      email: 'ommiicc@digital.justice.gov.uk'
    }
  end

  before(:each) do
    signin_spo_user

    create(:case_information, nomis_offender_id: nomis_offender_id)
  end

  context 'with just a primary POM allocated' do
    let!(:allocation) {
      create(
        :allocation,
        nomis_offender_id: nomis_offender_id,
        primary_pom_nomis_id: prison_pom[:staff_id],
        primary_pom_name: prison_pom[:pom_name],
        recommended_pom_type: 'probation'
      )
    }

    scenario 'show allocate a co-working POM page', vcr: { cassette_name: 'prison_api/show_allocate_coworking_page' } do
      visit new_prison_coworking_path('LEI', nomis_offender_id)

      expect(page).to have_link 'Back', href: prison_allocation_path('LEI', nomis_offender_id: nomis_offender_id)
      expect(page).to have_link('Allocate')
      expect(page).to have_css('h1', text: 'Allocate a co-working Prison Offender Manager')
      expect(page).to have_css('.govuk-table', count: 4)

      co_working_content = [
        'Prisoner Name Abbella, Ozullirn',
        'Date of birth 15/08/1980',
        'Prisoner number G4273GI',
        'Current POM Name',
        'Grade',
        'Available POMs',
        'Probation Officer POMs',
        'Prison Officer POMs'
      ]

      co_working_content.each do |text|
        expect(page).to have_content(text)
      end

      expect(page).not_to have_content('unavailable POM')
    end

    scenario 'show correct unavailable message', vcr: { cassette_name: 'prison_api/show_coworking_unavailable' } do
      inactive_poms = [485_758, 485_833]
      inactive_texts = ['There is 1 unavailable POM for new allocation',
                        'There are 2 unavailable POMs for new allocation']

      inactive_poms.each_with_index do |pom, i|
        visit edit_prison_pom_path('LEI', pom)
        choose('working_pattern-ft')
        choose('Inactive')
        click_button('Save')

        visit new_prison_coworking_path('LEI', nomis_offender_id)
        expect(page).to have_content(inactive_texts[i])
      end
    end

    scenario 'show confirm co-working POM allocation page', vcr: { cassette_name: 'prison_api/show_confirm_coworking_page' } do
      visit prison_confirm_coworking_allocation_path(
        'LEI',
        nomis_offender_id, prison_pom[:staff_id], secondary_pom[:staff_id]
            )

      expect(page).to have_content("Confirm co-working allocation")
      expect(page).to have_content("You are allocating co-working POM #{secondary_pom[:pom_name]} to Ozullirn Abbella. The responsible POM is #{prison_pom[:pom_name]}.")
      expect(page).to have_content("We will send a confirmation email to #{secondary_pom[:email]}")
      expect(page).to have_button('Complete allocation')
      expect(page).to have_link('Cancel')

      fill_in 'message', with: 'Some new information'

      click_button 'Complete allocation'

      expect(page).to have_current_path(unallocated_prison_prisoners_path('LEI'))

      allocation.reload
      expect(allocation.secondary_pom_nomis_id).to eq(secondary_pom[:staff_id])
      expect(allocation.secondary_pom_name).to eq("INTEGRATION-TESTS, MOIC")

      visit prison_allocation_path('LEI', nomis_offender_id)
      within '#co-working-pom' do
        expect(page).to have_content 'Remove'
        expect(page).to have_content 'Integration-Tests, Moic'
      end
    end
  end

  context 'with a secondary POM allocated' do
    let!(:allocation) {
      create(
        :allocation,
        nomis_offender_id: nomis_offender_id,
        primary_pom_nomis_id: prison_pom[:staff_id],
        primary_pom_name: prison_pom[:pom_name],
        secondary_pom_nomis_id: secondary_pom[:staff_id],
        secondary_pom_name: secondary_pom[:pom_name],
        recommended_pom_type: 'probation'
      )
    }

    before(:each) do
      visit prison_allocation_path('LEI', nomis_offender_id)

      within '#co-working-pom' do
        click_link 'Remove'
      end

      expect(page).to have_current_path('/prisons/LEI/coworking/G4273GI/confirm_coworking_removal')
      expect(page).to have_content "You are removing co-working POM #{secondary_pom[:pom_name]} who was working with Abbella, Ozullirn. The Supporting POM is #{prison_pom[:pom_name]}."
      expect(page).to have_content "We will send a confirmation email to #{prison_pom[:email]}"
    end

    scenario 'cancel removal of a co-working POM', vcr: { cassette_name: 'prison_api/coworking_pom_cancel' } do
      visit prison_allocation_path('LEI', nomis_offender_id)

      within '#co-working-pom' do
        click_link 'Remove'
      end

      expect(page).to have_current_path('/prisons/LEI/coworking/G4273GI/confirm_coworking_removal')
      click_link 'Cancel'

      expect(page).to have_current_path(prison_allocation_path('LEI', nomis_offender_id))
    end

    scenario 'removing a co-working POM', vcr: { cassette_name: 'prison_api/coworking_pom_remove' } do
      visit prison_allocation_path('LEI', nomis_offender_id)

      within '#co-working-pom' do
        click_link 'Remove'
      end

      expect(page).to have_current_path('/prisons/LEI/coworking/G4273GI/confirm_coworking_removal')

      click_button 'Confirm'
      expect(page).to have_current_path('/prisons/LEI/allocations/G4273GI')

      expect(page).to have_link 'Allocate'
      within '#co-working-pom' do
        expect(page).to have_content('N/A')
      end
    end
  end

  context 'with a secondary from somewhere else' do
    let(:another_pom) do
      {
        staff_id: 123_456,
        pom_name: 'Some Other POM',
        email: 'ommiicc@digital.justice.gov.uk'
      }
    end

    let!(:allocation) {
      create(
        :allocation,
        nomis_offender_id: nomis_offender_id,
        primary_pom_nomis_id: prison_pom[:staff_id],
        primary_pom_name: prison_pom[:pom_name],
        secondary_pom_nomis_id: another_pom[:staff_id],
        secondary_pom_name: another_pom[:pom_name],
        recommended_pom_type: 'probation'
      )
    }

    scenario 'allocating', vcr: { cassette_name: 'prison_api/coworking_with_another_pom' } do
      expect(allocation.secondary_pom_nomis_id).to eq(123456)
      visit prison_allocation_path('LEI', nomis_offender_id)

      click_link 'Allocate'

      within '.probation_pom_row_0' do
        click_link 'Allocate'
      end
      click_button 'Complete allocation'
      expect(allocation.reload.secondary_pom_nomis_id).to eq(485758)
      expect(page).to have_current_path(unallocated_prison_prisoners_path('LEI'), ignore_query: true)
    end
  end
end
