# frozen_string_literal: true

require 'rails_helper'

feature "early allocation", :allocation, type: :feature do
  let(:nomis_staff_id) { 485_926 }
  # any date less than 3 months
  let(:valid_date) { Time.zone.today - 2.months }
  let(:prison) { 'LEI' }
  let(:username) { 'MOIC_POM' }
  let(:nomis_offender) { build(:nomis_offender, sentence: attributes_for(:sentence_detail, conditionalReleaseDate: release_date)) }
  let(:nomis_offender_id) { nomis_offender.fetch(:offenderNo) }
  let(:pom) { build(:pom, staffId: nomis_staff_id) }

  before do
    create(:case_information, nomis_offender_id: nomis_offender_id)
    create(:allocation, prison: prison, nomis_offender_id: nomis_offender_id, primary_pom_nomis_id: nomis_staff_id)

    stub_auth_token
    stub_offenders_for_prison(prison, [nomis_offender])
    stub_offender(nomis_offender)
    stub_request(:get, "#{ApiHelper::T3}/users/#{username}").
      to_return(body: { 'staffId': nomis_staff_id }.to_json)
    stub_pom(pom)
    stub_poms(prison, [pom])
    stub_pom_emails(nomis_staff_id, [])
    stub_keyworker(prison, nomis_offender_id, build(:keyworker))

    signin_pom_user

    visit prison_staff_caseload_index_path(prison, nomis_staff_id)

    # assert that our setup created a caseload record
    expect(page).to have_content("Showing 1 - 1 of 1 results")
  end

  context 'without switch' do
    let(:release_date) { Time.zone.today }

    it 'does not show the section' do
      click_link "#{nomis_offender.fetch(:lastName)}, #{nomis_offender.fetch(:firstName)}"
      expect(page).not_to have_content 'Early allocation eligibility'
    end
  end

  context 'with switch' do
    let(:test_strategy) { Flipflop::FeatureSet.current.test! }

    before do
      test_strategy.switch!(:early_allocation, true)
    end

    after do
      test_strategy.switch!(:early_allocation, false)
    end

    context 'without existing early allocation' do
      before do
        click_link "#{nomis_offender.fetch(:lastName)}, #{nomis_offender.fetch(:firstName)}"
        expect(page).to have_content 'Early allocation eligibility'
        click_link 'Assess eligibility'
      end

      context 'when <= 18 months' do
        let(:release_date) { Time.zone.today + 17.months }

        scenario 'when an immediate error occurs' do
          click_button 'Continue'
          expect(page).to have_css('.govuk-error-message')
          expect(page).to have_css('#early-allocation-high-profile-error')
          within '.govuk-error-summary' do
            expect(page).to have_text 'You must say if this case is \'high profile\''
            click_link 'You must say if this case is \'high profile\''
            # ensure that page is still intact
            expect(all('li').map(&:text)).
                to match_array([
                                   "Enter the date of the last OASys risk assessment",
                                   "You must say if they are subject to a Serious Crime Prevention Order",
                                   "You must say if they were convicted under the Terrorism Act 2000",
                                   "You must say if this case is 'high profile'",
                                   "You must say if this is a MAPPA level 3 case",
                                   "You must say if this will be a CPPC case"
                               ]
            )
          end
        end

        context 'when doing stage1 happy path' do
          before do
            stage1_eligible_answers
          end

          scenario 'stage1 happy path' do
            expect {
              click_button 'Continue'
              expect(page).not_to have_css('.govuk-error-message')
              # selecting any one of these as 'Yes' means that we progress to assessment complete (Yes)
              expect(page).to have_text('The community probation team will take responsibility')
              expect(page).to have_text('A new handover date will be calculated automatically')
            }.to change(EarlyAllocation, :count).by(1)
            click_link 'Return to prisoner page'
            expect(page).to have_text 'Eligible'
          end

          scenario 'displaying the PDF' do
            click_button 'Continue'
            expect(page).not_to have_css('.govuk-error-message')
            # selecting any one of these as 'Yes' means that we progress to assessment complete (Yes)
            expect(page).to have_text('The community probation team will take responsibility')
            click_link 'Save completed assessment (pdf)'
            expect(page).to have_current_path("/prisons/#{prison}/prisoners/#{nomis_offender_id}/early_allocation.pdf")
          end
        end

        context 'with stage 2 questions' do
          before do
            stage1_stage2_answers

            click_button 'Continue'
            # make sure that we are displaying stage 2 questions before continuing
            expect(page).to have_text 'Has the prisoner been held in an extremism'
          end

          scenario 'error path' do
            click_button 'Continue'

            expect(page).to have_css('.govuk-error-message')
            expect(page).to have_css('.govuk-error-summary')

            within '.govuk-error-summary' do
              expect(page).to have_text 'You must say if this is a MAPPA level 2 case'

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
            before do
              discretionary_stage2_answers

              click_button 'Continue'
              expect(page).not_to have_text 'The community probation team will make a decision'

              # Last prompt before end of journey
              expect(page).to have_text 'Why are you referring this case for early allocation to the community?'
              click_button 'Continue'
              # we need to always tick the 'Head of Offender Management' box and fill in the reasons
              expect(page).to have_css('.govuk-error-message')

              expect {
                complete_form
              }.to change(EarlyAllocation, :count).by(1)

              expect(page).to have_text 'The community probation team will make a decision'
            end

            scenario 'saving the PDF' do
              click_link 'Save completed assessment (pdf)'
              expect(page).to have_current_path("/prisons/#{prison}/prisoners/#{nomis_offender_id}/early_allocation.pdf")
            end

            scenario 'completing the journey', :js do
              click_link 'Return to prisoner page'
              expect(page).to have_content 'Waiting for community decision'
              within '#early_allocation' do
                click_link 'Update'
              end

              click_button('Save')
              expect(page).to have_css('.govuk-error-message')
              within '.govuk-error-summary' do
                expect(all('li').count).to eq(1)
              end
              expect(page).to have_text 'You must say whether the community has accepted this case or not'

              find('label[for=early_allocation_community_decision_true]').click
              click_button('Save')
              expect(page).to have_text('Re-assess')
              expect(page).to have_text 'Eligible'
            end
          end

          scenario 'not eligible due to all answers false' do
            find('#early-allocation-extremism-separation-field').click
            find('#early-allocation-high-risk-of-serious-harm-field').click
            find('#early-allocation-mappa-level-2-field').click
            find('#early-allocation-pathfinder-process-field').click
            find('#early-allocation-other-reason-field').click

            click_button 'Continue'
            expect(page).to have_text 'Not eligible for early allocation'
            click_link 'Save completed assessment (pdf)'
            expect(page).to have_current_path("/prisons/#{prison}/prisoners/#{nomis_offender_id}/early_allocation.pdf")
          end
        end
      end

      context 'when > 18 months', :js do
        let(:release_date) { Time.zone.today + 19.months }

        context 'when stage 1 happy path - not sent' do
          before do
            expect(EarlyAllocationMailer).not_to receive(:auto_early_allocation)
          end

          it 'doesnt send the email' do
            expect {
              stage1_eligible_answers
              click_button 'Continue'
              expect(page).to have_text('The community probation team will take responsibility for this case early')
              expect(page).to have_text('The assessment has not been sent to the community probation team')
            }.not_to change(EmailHistory, :count)
          end
        end

        context 'with discretionary result' do
          before do
            expect(EarlyAllocationMailer).not_to receive(:community_early_allocation)
          end

          it 'doesnt send the email' do
            expect {
              stage1_stage2_answers
              click_button 'Continue'
              discretionary_stage2_answers
              click_button 'Continue'
              complete_form
              expect(page).to have_text('The assessment has not been sent to the community probation team')
            }.not_to change(EmailHistory, :count)
          end
        end
      end
    end

    context 'when existing eligible early allocation' do
      let(:release_date) { Time.zone.today + 17.months }

      before do
        create(:early_allocation, :discretionary,
               nomis_offender_id: nomis_offender_id,
               community_decision: true)
        click_link "#{nomis_offender.fetch(:lastName)}, #{nomis_offender.fetch(:firstName)}"
      end

      it 'has a re-assess link' do
        expect(page).to have_link 'Re-assess'
      end

      context 'when reassessing' do
        before do
          within '#early_allocation' do
            click_link 'Re-assess'
          end
        end

        it 'creates a new assessment' do
          expect {
            stage1_eligible_answers
            click_button 'Continue'
          }.to change(EarlyAllocation, :count).by(1)
        end

        it 'can do stage2' do
          stage1_stage2_answers
          click_button 'Continue'
          expect(page).not_to have_css('.govuk-error-message')
        end
      end
    end
  end

  def stage1_eligible_answers
    fill_in id: 'early_allocation_oasys_risk_assessment_date_3i', with: valid_date.day
    fill_in id: 'early_allocation_oasys_risk_assessment_date_2i', with: valid_date.month
    fill_in id: 'early_allocation_oasys_risk_assessment_date_1i', with: valid_date.year

    find('label[for=early-allocation-convicted-under-terrorisom-act-2000-true-field]').click
    find('label[for=early-allocation-high-profile-field]').click
    find('label[for=early-allocation-serious-crime-prevention-order-field]').click
    find('label[for=early-allocation-mappa-level-3-field]').click
    find('label[for=early-allocation-cppc-case-field]').click
  end

  def stage1_stage2_answers
    fill_in id: 'early_allocation_oasys_risk_assessment_date_3i', with: valid_date.day
    fill_in id: 'early_allocation_oasys_risk_assessment_date_2i', with: valid_date.month
    fill_in id: 'early_allocation_oasys_risk_assessment_date_1i', with: valid_date.year

    find("label[for=early-allocation-convicted-under-terrorisom-act-2000-field]").click
    find('label[for=early-allocation-high-profile-field]').click
    find('label[for=early-allocation-serious-crime-prevention-order-field]').click
    find('label[for=early-allocation-mappa-level-3-field]').click
    find('label[for=early-allocation-cppc-case-field]').click
  end

  def discretionary_stage2_answers
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
end
