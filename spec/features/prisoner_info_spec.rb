require 'rails_helper'

feature 'View a prisoner profile page' do
  before do
    signin_spo_user([prison.code])
  end

  let(:prison) { build(:prison, code: 'LEI') }

  context 'without allocation or case information' do
    it 'doesnt crash', vcr: { cassette_name: 'prison_api/show_unallocated_offender' } do
      visit prison_prisoner_path(prison.code, 'G7266VD')

      expect(page).to have_css('h1', text: 'Annole, Omistius')
      expect(page).to have_content('26 Sep 1994')
      cat_code = find('h3#category-code').text
      expect(cat_code).to eq('Cat B')
      expect(page).to have_css('#prisoner-case-type', text: 'Determinate')
    end
  end

  context 'with an existing early allocation', vcr: { cassette_name: 'prison_api/early_allocation_banner' } do
    before do
      create(:case_information,
             offender: build(:offender, nomis_offender_id: 'G7266VD',
                             parole_record: build(:parole_record, parole_review_date: Time.zone.today + 1.year),
             early_allocations: [build(:early_allocation, created_within_referral_window: within_window)]))
      visit prison_prisoner_path(prison.code, 'G7266VD')
    end

    context 'with an old early allocation' do
      let(:within_window) { false }

      it 'shows a notification', :js do
        expect(page).to have_text('Annole, Omistius might be eligible for early allocation to the community probation team')
      end
    end

    context 'with an new early allocation' do
      let(:within_window) { true }

      it 'does not show a notification', :js do
        expect(page).not_to have_text('eligible for early allocation to the community probation team')
      end
    end
  end

  context 'with an allocation', :allocation do
    before do
      create(:case_information, offender: build(:offender, nomis_offender_id: 'G7266VD', victim_liaison_officers: [build(:victim_liaison_officer)]))
      create(:allocation_history, :co_working, prison: prison.code, nomis_offender_id: 'G7266VD', primary_pom_nomis_id: '485637', primary_pom_name: 'Pobno, Kath')
    end

    let(:allocation) { AllocationHistory.last }
    let(:initial_vlo) { VictimLiaisonOfficer.last }

    context 'without anything extra', vcr: { cassette_name: 'prison_api/show_offender_spec' }  do
      before do
        visit prison_prisoner_path(prison.code, 'G7266VD')
      end

      scenario 'adding a VLO', :js do
        expect(page).to have_content('First Contact')
        click_link 'Add new VLO contact'
        find('.govuk-back-link')
        click_link 'Back'
        click_link 'Add new VLO contact'

        fill_in 'First name', with: 'Jim'
        # This fails as all fields not filled
        click_button 'Submit'

        # fill in missing fields and submit
        fill_in 'Last name', with: 'Smith'
        # email has leading and trailing whitespaces, that are removed before validation
        fill_in 'Email address', with: ' jim.smith@hotmail.com '
        click_button 'Submit'
        find '.vlo-row-1' # wait for page to load
        expect(page).to have_content('Smith, Jim')
        expect(page).to have_content('Second Contact')

        # As we had one already, ours is the second contact
        within '.vlo-row-1' do
          within '.change-email' do
            click_link 'Change'
          end
        end
        find('.govuk-back-link')
        click_link 'Back'
        find '.vlo-row-1' # wait for page to re-load
        within '.vlo-row-1' do
          within '.change-email' do
            click_link 'Change'
          end
        end

        # Blank out first name so it fails
        fill_in 'First name', with: ''
        click_button 'Submit'

        # Change first name
        fill_in 'First name', with: 'Mike'
        click_button 'Submit'
        expect(page).to have_content('Smith, Mike')

        # delete the contact we added earlier
        within '.vlo-row-1' do
          click_link 'Delete Contact'
        end
        click_button 'Confirm'
        # We should come back to the same page, but with our contact deleted
        expect(page).to have_content(initial_vlo.full_name)
        expect(page).not_to have_content('Smith, Mike')

        # Let's go and check out the allocation history
        click_link 'View'
        expect(page).to have_content('Victim Liaison Officer contact removed')
        expect(page).to have_content('by Pom, Moic')
      end

      it 'shows the prisoner information' do
        expect(page).to have_css('h1', text: 'Annole, Omistius')
        expect(page).to have_content('26 Sep 1994')
        cat_code = find('h3#category-code').text
        expect(cat_code).to eq('Cat B')
      end

      it 'shows the POM name (fetched from NOMIS)' do
        # check the primary POM name stored in the allocation
        expect(allocation.primary_pom_name).to eq('Pobno, Kath')

        # ensure that the POM name displayed is the one actually returned from NOMIS
        pom_name = find('#primary_pom_name').text
        expect(pom_name).to eq('Pobee-Norris, Kath')
      end

      it 'shows the prisoner image', vcr: { cassette_name: 'prison_api/show_offender_spec_image' } do
        visit prison_prisoner_image_path(prison.code, 'G7266VD', format: :jpg)
        expect(page.response_headers['Content-Type']).to eq('image/jpg')
      end

      it "has a link to the allocation history", vcr: { cassette_name: 'prison_api/link_to_allocation_history' } do
        visit prison_prisoner_path(prison.code, 'G7266VD')
        click_link "View"
        expect(page).to have_content('Prisoner allocated')
      end

      it 'displays the non-disclosable badge on the VLO table', vcr: { cassette_name: 'prison_api/vlo_non_disclosable_badge' } do
        visit prison_prisoner_path(prison.code, 'G7266VD')
        expect(page).to have_css('#non-disclosable-badge', text: 'Non-Disclosable')
      end
    end

    context 'with an overridden reponsibility' do
      before do
        create(:responsibility, nomis_offender_id: 'G7266VD')
      end

      it 'shows an overridden responsibility', vcr: { cassette_name: 'prison_api/show_offender_with_override_spec' } do
        visit prison_prisoner_path(prison.code, 'G7266VD')

        expect(page).to have_content('Supporting')
      end
    end
  end

  describe 'community information' do
    context 'with an email address' do
      let(:ldu) { create(:local_delivery_unit, name: 'An LDU', email_address: 'test@example.com') }
      let(:team_name) { 'A Nice team' }

      before do
        create(:case_information,
               offender: build(:offender, nomis_offender_id: 'G7266VD'),
               local_delivery_unit: ldu,
               team_name: team_name,
               com_name: 'Bob Smith'
        )
      end

      it "has community information", vcr: { cassette_name: 'prison_api/show_offender_community_info_full' } do
        visit prison_prisoner_path(prison.code, 'G7266VD')

        expect(page).to have_content(ldu.name)
        expect(page).to have_content(ldu.email_address)
        expect(page).to have_content(team_name)
        expect(page).to have_content('Bob Smith')
      end
    end

    context 'without email address or com name' do
      before do
        create(:case_information,
               offender: build(:offender, nomis_offender_id: 'G7266VD'),
        )

        visit prison_prisoner_path(prison.code, 'G7266VD')
      end

      it "displays team and LDU as unknown", :js, vcr: { cassette_name: 'prison_api/show_offender_community_info_partial' } do
        # Expect an Unknown for LDU Email and Team
        within '#community_information' do
          expect(page).to have_content('Unknown', count: 2)
        end
      end
    end
  end

  context 'when offender does not have a sentence start date',
          vcr: { cassette_name: 'prison_api/no_sentence_start_date_for_offender' } do
    let(:api_non_sentenced_offender) do
      build(:hmpps_api_offender,
            agencyId: prison.code,
            offenderNo: 'G7266VD',
            imprisonmentStatus: 'SEC90',
            sentence: build(:sentence_detail,
                            releaseDate: 3.years.from_now.iso8601,
                            sentenceStartDate: nil))
    end
    let(:case_info) { create(:case_information, case_allocation: CaseInformation::NPS, offender: build(:offender, nomis_offender_id: 'G7998GJ')) }
    let(:non_sentenced_offender) {
      build(:mpc_offender, prison: prison, offender: case_info.offender, prison_record: api_non_sentenced_offender)
    }

    before do
      allow(OffenderService).to receive(:get_offender).and_return(non_sentenced_offender)
    end

    it 'shows the page without crashing' do
      visit prison_prisoner_path(prison.code, 'G7998GJ')

      within '#handover-start-date' do
        expect(page).to have_content('N/A')
      end

      within '#responsibility-handover' do
        expect(page).to have_content('N/A')
      end

      within '#sentence-start-date' do
        expect(page).to have_content('N/A')
      end
    end
  end

  context "when the offender needs a COM but one isn't allocated" do
    let!(:case_info) {
      create(:case_information,
             offender: build(:offender, nomis_offender_id: nomis_offender_id),
             local_delivery_unit: build(:local_delivery_unit)
      )
    }

    let(:nomis_offender) {
      build(:nomis_offender, agencyId: prison.code, sentence: attributes_for(:sentence_detail, :inside_handover_window))
    }

    let(:nomis_offender_id) { nomis_offender.fetch(:offenderNo) }
    let!(:prison) { create(:prison) }

    before do
      stub_auth_token
      stub_user(staff_id: 1234)
      stub_keyworker(prison.code, nomis_offender_id, build(:keyworker))
      stub_offender(nomis_offender)
    end

    it 'shows an error message at the top of the page' do
      visit prison_prisoner_path(prison.code, nomis_offender_id)
      within '.govuk-error-summary' do
        expect(page).to have_content 'A Community Offender Manager (COM) must be allocated to this case'
      end
    end

    it 'highlights the "COM name" table row in red' do
      visit prison_prisoner_path(prison.code, nomis_offender_id)
      expect(page).to have_css('#com-name.govuk-table__cell-error')
    end

    describe 'clicking on the warning message', :js do
      it 'jumps the user down to the "COM name" table row' do
        visit prison_prisoner_path(prison.code, nomis_offender_id)
        click_link 'A Community Offender Manager (COM) must be allocated to this case'
        expect(current_url).to end_with('#com-name')
      end
    end

    context 'when the LDU has already been emailed automatically' do
      let(:date_sent) { 2.days.ago }

      let!(:email_history) {
        create(:email_history, :open_prison_community_allocation,
               nomis_offender_id: nomis_offender_id,
               created_at: date_sent
        )
      }

      it 'says that an email has been sent' do
        visit prison_prisoner_path(prison.code, nomis_offender_id)
        within '.govuk-error-summary' do
          reload_page
          date = date_sent.to_date.to_s(:rfc822)
          expect(page).to have_content "We automatically emailed the LDU asking them to allocate a COM on #{date}"
        end
      end
    end

    describe 'after a COM has been allocated (pulled in via nDelius/Community API)' do
      before do
        case_info.update!(com_name: "#{Faker::Name.last_name}, #{Faker::Name.first_name}")
      end

      it 'does not show' do
        visit prison_prisoner_path(prison.code, nomis_offender_id)
        expect(page).not_to have_css('.govuk-error-summary')
        expect(page).not_to have_content('A Community Offender Manager (COM) must be allocated to this case')
        expect(page).not_to have_css('#com-name.govuk-table__cell-error')
      end
    end
  end
end
