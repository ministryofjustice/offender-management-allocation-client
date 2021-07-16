# frozen_string_literal: true

require 'rails_helper'

feature "early allocation", :disable_early_allocation_event, type: :feature do
  let(:nomis_staff_id) { 485_926 }
  # any date less than 3 months
  let(:valid_date) { Time.zone.today - 2.months }
  let!(:prison) { create(:prison).code }
  let(:username) { 'MOIC_POM' }
  let(:nomis_offender) { build(:nomis_offender, agencyId: prison, dateOfBirth: date_of_birth, sentence: attributes_for(:sentence_detail, conditionalReleaseDate: release_date)) }
  let(:nomis_offender_id) { nomis_offender.fetch(:offenderNo) }
  let(:pom) { build(:pom, staffId: nomis_staff_id) }
  let(:date_of_birth) { Date.new(1980, 1, 6).to_s }
  let(:offender_name) { "#{nomis_offender.fetch(:lastName)}, #{nomis_offender.fetch(:firstName)}" }
  let(:case_alloc) { CaseInformation::NPS }

  before do
    create(:case_information, offender: build(:offender, nomis_offender_id: nomis_offender_id), case_allocation: case_alloc)
    create(:allocation_history, prison: prison, nomis_offender_id: nomis_offender_id, primary_pom_nomis_id: nomis_staff_id)

    stub_auth_token
    stub_offenders_for_prison(prison, [nomis_offender])
    stub_request(:get, "#{ApiHelper::T3}/users/#{username}").
      to_return(body: { 'staffId': nomis_staff_id }.to_json)
    stub_pom(pom)
    stub_poms(prison, [pom])
    stub_pom_emails(nomis_staff_id, [])
    stub_keyworker(prison, nomis_offender_id, build(:keyworker))

    signin_pom_user([prison])

    visit prison_staff_caseload_path(prison, nomis_staff_id)

    # assert that our setup created a caseload record
    expect(page).to have_content("Showing 1 - 1 of 1 results")
  end

  context 'with switch set false' do
    let(:test_strategy) { Flipflop::FeatureSet.current.test! }
    let(:release_date) { Time.zone.today }

    before do
      test_strategy.switch!(:early_allocation, false)
    end

    after do
      test_strategy.switch!(:early_allocation, true)
    end

    it 'does not show the section' do
      click_link offender_name
      expect(page).not_to have_content 'Early allocation eligibility'
    end
  end

  # switch is on by default
  context 'with switch' do
    context 'when CRC' do
      let(:case_alloc) { CaseInformation::CRC }
      let(:release_date) { Time.zone.today }

      it 'does not show the section' do
        click_link offender_name
        expect(page).not_to have_content 'Early allocation eligibility'
      end
    end

    context 'without existing early allocation' do
      before do
        click_link offender_name

        # Prisoner profile page
        expect(page).to have_content 'Early allocation referral'
        click_link 'Start assessment'

        # Early Allocation start page
        expect(page).to have_content 'Early allocation assessment process'
        #expect(page).to have_content 'This case has no saved assessments.'
        displays_prisoner_information_in_side_panel
        click_link 'Start new assessment'
      end

      context 'when <= 18 months' do
        let(:release_date) { Time.zone.today + 17.months }

        scenario 'when first page with just date', :js do
          click_button 'Continue'
          expect(page).to have_css('.govuk-error-message')
          within '.govuk-error-summary' do
            expect(all('li').map(&:text))
                .to match_array([
                                    "Enter the date of the last OASys risk assessment",
                                ])
          end
        end

        scenario 'when an immediate error occurs on the second page' do
          fill_in_date_form

          click_button 'Continue'
          expect(page).to have_css('.govuk-error-message')
          expect(page).to have_css('#early-allocation-high-profile-error')
          within '.govuk-error-summary' do
            expect(page).to have_text 'You must say if this case is \'high profile\''
            click_link 'You must say if this case is \'high profile\''
            # ensure that page is still intact
            expect(all('li').map(&:text)).
                to match_array([
                                   "You must say if they are subject to a Serious Crime Prevention Order",
                                   "You must say if they were convicted under the Terrorism Act 2000",
                                   "You must say if this case is 'high profile'",
                                   "You must say if this is a MAPPA level 3 case",
                                   "You must say if this will be a CPPC case"
                               ]
            )
          end
        end

        context 'when doing eligible happy path' do
          before do
            eligible_eligible_answers
          end

          scenario 'eligible happy path' do
            expect {
              displays_prisoner_information_in_side_panel
              click_button 'Continue'
              expect(page).not_to have_css('.govuk-error-message')
              # selecting any one of these as 'Yes' means that we progress to assessment complete (Yes)
              expect(page).to have_text('The community probation team will take responsibility')
              expect(page).to have_text('A new handover date will be calculated automatically')
            }.to change(EarlyAllocation, :count).by(1)

            # Early allocation status is updated
            click_link 'Return to prisoner page'
            expect(page).to have_text 'Eligible'
            expect(page).to have_link 'View assessment'

            # Can view the assessment
            click_link 'View assessment'
            expect(page).to have_text 'View previous early allocation assessment'
          end

          scenario 'displaying the PDF' do
            click_button 'Continue'
            expect(page).not_to have_css('.govuk-error-message')
            # selecting any one of these as 'Yes' means that we progress to assessment complete (Yes)
            expect(page).to have_text('The community probation team will take responsibility')
            click_link 'Save completed assessment (pdf)'

            created_id = EarlyAllocation.last.id
            expected_path = "/prisons/#{prison}/prisoners/#{nomis_offender_id}/early_allocations/#{created_id}.pdf"
            expect(page).to have_current_path(expected_path)
          end
        end

        context 'with stage 2 questions' do
          before do
            eligible_discretionary_answers
            displays_prisoner_information_in_side_panel
            click_button 'Continue'
            # make sure that we are displaying stage 2 questions before continuing
            expect(page).to have_text 'Has the prisoner been held in an extremism'
          end

          scenario 'error path' do
            click_button 'Continue'

            expect(page).to have_css('.govuk-error-message')
            expect(page).to have_css('.govuk-error-summary')

            within '.govuk-error-summary' do
              expect(all('li').map(&:text)).
                to match_array([
                          "You must say if this prisoner has been in an extremism separation centre",
                          "You must say if there is another reason for early allocation",
                          "You must say whether this prisoner presents a risk of serious harm",
                          "You must say if this is a MAPPA level 2 case",
                          "You must say if this prisoner has been identified through the pathfinder process"
                      ]
                   )
            end
          end

          context 'with discretionary path' do
            let(:early_allocation_state) { page.find('#early-allocation-badge') }

            before do
              discretionary_discretionary_answers
              click_button 'Continue'
              expect(page).not_to have_text 'The community probation team will make a decision'
              displays_prisoner_information_in_side_panel
                # Last prompt before end of journey
              expect(page).to have_text 'Why are you referring this case for early allocation to the community?'
              click_button 'Continue'
                # we need to always tick the 'Head of Offender Management' box and fill in the reasons
              expect(page).to have_css('.govuk-error-message')
              within '.govuk-error-summary' do
                expect(all('li').map(&:text)).
                    to match_array([
                                       "You must give a reason for referring this case",
                                       "You must say if this referral has been approved",
                                   ]
                       )
              end

              expect {
                complete_form
              }.to change(EarlyAllocation, :count).by(1)

              expect(page).to have_text 'The community probation team will make a decision'
            end

            scenario 'saving the PDF' do
              created_id = EarlyAllocation.last.id
              expected_path = "/prisons/#{prison}/prisoners/#{nomis_offender_id}/early_allocations/#{created_id}.pdf"
              expect(page).to have_link 'Save completed assessment (pdf)', href: expected_path
            end

            scenario 'completing the journey' do
              # Profile page
              click_link 'Return to prisoner page'
              expect(page).to have_content 'Discretionary - the community probation team will make a decision'
              click_link 'Record community decision'

              # 'Record community decision' page
              displays_prisoner_information_in_side_panel
              click_button('Save')
              expect(page).to have_css('.govuk-error-message')
              within '.govuk-error-summary' do
                expect(all('li').count).to eq(1)
              end
              expect(page).to have_text 'You must say whether the community has accepted this case or not'

              find('label[for=early_allocation_community_decision_true]').click
              click_button('Save')

              # Profile page
              expect(page).to have_text 'Eligible - case handover date has been updated'
              expect(page).to have_link 'View assessment'

              # View the assessment
              click_link 'View assessment'
              expect(page).to have_text 'View previous early allocation assessment'
            end
          end

          scenario 'not eligible due to all answers false' do
            find('label[for=early-allocation-extremism-separation-field]').click
            find('label[for=early-allocation-high-risk-of-serious-harm-field]').click
            find('label[for=early-allocation-mappa-level-2-field]').click
            find('label[for=early-allocation-pathfinder-process-field]').click
            find('label[for=early-allocation-other-reason-field]').click

            click_button 'Continue'
            expect(page).to have_text 'Not eligible for early allocation'
            click_link 'Save completed assessment (pdf)'

            created_id = EarlyAllocation.last.id
            expected_path = "/prisons/#{prison}/prisoners/#{nomis_offender_id}/early_allocations/#{created_id}.pdf"
            expect(page).to have_current_path(expected_path)
          end
        end
      end

      context 'when > 18 months' do
        let(:release_date) { Time.zone.today + 19.months }

        context 'when stage 1 happy path - not sent' do
          before do
            expect(EarlyAllocationMailer).not_to receive(:auto_early_allocation)
          end

          it 'doesnt send the email' do
            expect {
              eligible_eligible_answers
              click_button 'Continue'
              expect(page).to have_text('The community probation team will take responsibility for this case early')
              expect(page).to have_text('The assessment has not been sent to the community probation team')
            }.not_to change(EmailHistory, :count)

            # Early allocation status is updated
            click_link 'Return to prisoner page'
            expect(page).to have_text 'Has saved assessments'
            expect(page).to have_link 'Check and reassess'
          end
        end

        context 'with discretionary result' do
          before do
            expect(EarlyAllocationMailer).not_to receive(:community_early_allocation)
          end

          it 'doesnt send the email' do
            expect {
              eligible_discretionary_answers
              click_button 'Continue'
              discretionary_discretionary_answers
              click_button 'Continue'
              complete_form
              expect(page).to have_text('The assessment has not been sent to the community probation team')
            }.not_to change(EmailHistory, :count)

            # Early allocation status is updated
            click_link 'Return to prisoner page'
            expect(page).to have_text 'Has saved assessments'
            expect(page).to have_link 'Check and reassess'
          end
        end
      end
    end

    context 'with existing Early Allocation assessments' do
      context 'when <= 18 months' do
        let(:release_date) { Time.zone.today + 17.months }

        context 'when assessment outcome was eligible and was sent to LDU' do
          before do
            # Was sent to LDU because created_within_referral_window is true
            create(:early_allocation,
                   nomis_offender_id: nomis_offender_id,
                   created_within_referral_window: true)

            click_link offender_name
          end

          it 'links to the view page' do
            click_link 'View assessment'
            expect(page).to have_text 'View previous early allocation assessment'
          end

          it 'does not have a re-assess link' do
            expect(page).not_to have_link 'Check and reassess'
          end
        end

        context 'when assessment outcome was not eligible' do
          before do
            create(:early_allocation, :ineligible,
                   nomis_offender_id: nomis_offender_id,
                   created_within_referral_window: true)

            click_link offender_name
          end

          it 'has a re-assess link' do
            expect(page).to have_link 'Check and reassess'
          end
        end
      end

      context 'when > 18 months' do
        let(:release_date) { Time.zone.today + 19.months }

        context 'when assessment outcome was eligible' do
          before do
            create(:early_allocation,
                   nomis_offender_id: nomis_offender_id,
                   created_within_referral_window: false)

            click_link offender_name
          end

          it 'has a re-assess link' do
            expect(page).to have_link 'Check and reassess'
          end
        end
      end

      context 'when reassessing' do
        let(:release_date) { Time.zone.today + 17.months }

        before do
          create(:early_allocation, :ineligible,
                 nomis_offender_id: nomis_offender_id,
                 created_within_referral_window: true)

          click_link offender_name

          within '#early_allocation' do
            click_link 'Check and reassess'
          end

          # Early Allocation start page
          expect(page).not_to have_content 'This case has no saved assessments.'
          displays_prisoner_information_in_side_panel
          click_link 'Start new assessment'
        end

        it 'creates a new assessment' do
          expect {
            eligible_eligible_answers
            click_button 'Continue'
          }.to change(EarlyAllocation, :count).by(1)
        end

        it 'can do discretionary' do
          eligible_discretionary_answers
          click_button 'Continue'
          expect(page).not_to have_css('.govuk-error-message')
        end
      end

      describe 'Early Allocation start page' do
        let(:release_date) { Time.zone.today + 19.months }

        before do
          create(:early_allocation, :ineligible,
                 created_at: 5.days.ago,
                 nomis_offender_id: nomis_offender_id,
                 created_within_referral_window: false)

          create(:early_allocation, :eligible,
                 created_at: 3.days.ago,
                 nomis_offender_id: nomis_offender_id,
                 created_within_referral_window: false)

          create(:early_allocation, :discretionary,
                 created_at: 1.day.ago,
                 nomis_offender_id: nomis_offender_id,
                 created_within_referral_window: false)

          click_link offender_name
          within '#early_allocation' do
            click_link 'Check and reassess'
          end
        end

        it 'displays a list of previous assessments' do
          table_rows = page.all('#saved_assessments > tbody > tr')

          expect(page).to have_content 'View saved assessments'

          # Expect 3 rows in the table
          expect(table_rows.count).to eq(3)

          # 1. Discretionary (most recent)
          expect(table_rows[0]).to have_content 'Discretionary - assessment not sent to the community probation team'

          # 2. Eligible
          expect(table_rows[1]).to have_content 'Eligible - assessment not sent to the community probation team'

          # 3. Not eligible (oldest)
          expect(table_rows[2]).to have_content 'Not eligible'
        end

        describe 'clicking "View" on a previous assessment' do
          it 'shows you the chosen assessment' do
            # Click 'View' on the 2nd row of table (should be an 'eligible' assessment)
            within '#saved_assessments > tbody > tr:nth-child(2)' do
              click_link 'View'
            end

            # We're on the 'View' page
            expect(page).to have_content 'View previous early allocation assessment'
            expect(page).to have_content 3.days.ago.to_date.to_s(:rfc822)
            expect(page).to have_content 'Eligible - assessment not sent to the community probation team'
          end
        end
      end
    end
  end

  def fill_in_date_form
    fill_in id: 'early_allocation_oasys_risk_assessment_date_3i', with: valid_date.day
    fill_in id: 'early_allocation_oasys_risk_assessment_date_2i', with: valid_date.month
    fill_in id: 'early_allocation_oasys_risk_assessment_date_1i', with: valid_date.year

    click_button 'Continue'
  end

  def eligible_eligible_answers
    fill_in_date_form

    find('label[for=early-allocation-convicted-under-terrorisom-act-2000-true-field]').click
    find('label[for=early-allocation-high-profile-field]').click
    find('label[for=early-allocation-serious-crime-prevention-order-field]').click
    find('label[for=early-allocation-mappa-level-3-field]').click
    find('label[for=early-allocation-cppc-case-field]').click
  end

  def eligible_discretionary_answers
    fill_in_date_form

    find("label[for=early-allocation-convicted-under-terrorisom-act-2000-field]").click
    find('label[for=early-allocation-high-profile-field]').click
    find('label[for=early-allocation-serious-crime-prevention-order-field]').click
    find('label[for=early-allocation-mappa-level-3-field]').click
    find('label[for=early-allocation-cppc-case-field]').click
  end

  def discretionary_discretionary_answers
    find('label[for=early-allocation-extremism-separation-field]').click
    find('label[for=early-allocation-high-risk-of-serious-harm-field]').click
    find('label[for=early-allocation-mappa-level-2-field]').click
    find('label[for=early-allocation-pathfinder-process-field]').click
    find('label[for=early-allocation-other-reason-true-field]').click
  end

  def complete_form
    fill_in id: 'early_allocation_reason', with: Faker::Quote.famous_last_words
    find('label[for=early_allocation_approved]').click
    click_button 'Continue'
  end

  def displays_prisoner_information_in_side_panel
    expect(page).to have_text('Prisoner information')
    expect(page).to have_selector('p#prisoner-name', text: offender_name)
    expect(page).to have_selector('p#date-of-birth', text: '06 Jan 1980')
    expect(page).to have_selector('p#nomis-number', text: nomis_offender_id)
  end
end
