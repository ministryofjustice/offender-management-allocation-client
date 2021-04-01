# frozen_string_literal: true

require 'rails_helper'

feature 'Case history with complexity level' do
  before do
    test_strategy.switch!(:womens_estate, true)

    allow(HmppsApi::ComplexityApi).to receive(:get_history).with(offender_no).and_return(history)
    stub_signin_spo logged_in_user, [prison_code]
    stub_offenders_for_prison prison_code, [offender]
    stub_poms prison_code, [pom]

    stub_request(:get, "#{ApiHelper::T3}/users/user").
      to_return(body: { staffId: pom.staff_id, firstName: pom.first_name, lastName: pom.last_name }.to_json)

    create(:allocation, prison: prison_code, nomis_offender_id: offender_no,
           allocated_at_tier: case_info.tier,
           created_by_name: created_by_name,
           primary_pom_nomis_id: pom.staff_id, primary_pom_name: pom_name)

    visit prison_allocation_history_path(prison_code, offender_no)
  end

  after do
    test_strategy.switch!(:womens_estate, false)
  end

  let(:test_strategy) { Flipflop::FeatureSet.current.test! }
  let(:now) { Time.zone.now }
  let(:complexity_add_time) { now - 1.hour }
  let(:complexity_change_time) { now + 1.hour }
  let(:username) { 'user' }
  let(:logged_in_user) { build(:pom) }
  let(:pom) { build(:pom) }
  let(:pom_name) { "#{pom.last_name}, #{pom.first_name}" }
  let(:prison) { build(:womens_prison) }
  let(:prison_code) { prison.code }
  let(:case_info) { create(:case_information) }
  let(:offender_no) { case_info.nomis_offender_id }
  let(:offender) { build(:nomis_offender, offenderNo: offender_no) }
  let(:created_by_name) { "#{logged_in_user.last_name}, #{logged_in_user.first_name}" }

  context 'with 1 history record' do
    let(:history) {
      [{ level: 'high',
         createdTimeStamp: complexity_add_time,
         sourceUser: username }]
    }

    it 'has 1 prison section' do
      expect(all('.govuk-grid-row').size).to eq(1)
    end

    it 'has a section with complexity and allocation' do
      within '.govuk-grid-row:nth-of-type(1)' do
        expect(page).to have_css('.govuk-heading-m', text: prison.name)
        expect(all('.moj-timeline__item').size).to eq(2)
      end
    end

    # have to put :js here as \n is handled differently between Capybara and Rack::Test
    it 'has a section with the allocation in it', :js do
      within '.govuk-grid-row:nth-of-type(1)' do
        within '.moj-timeline__item:nth-of-type(1)' do
          [
            ['.moj-timeline__description', [
              "Prisoner allocated to #{pom_name.titleize} - #{pom.emails.first}\n",
              "Tier: #{case_info.tier}"
            ].join],
            ['.moj-timeline__date', "#{formatted_date_for(now)} by #{created_by_name.titleize}"],
          ].each do |key, val|
            expect(page).to have_css(key, text: val)
          end
        end
      end
    end

    it 'has a section with the level in it' do
      within '.govuk-grid-row:nth-of-type(1)' do
        within '.moj-timeline__item:nth-of-type(2)' do
          [
            ['.moj-timeline__title', 'Complexity of need level added'],
            ['.moj-timeline__description', 'Level: High'],
            ['.moj-timeline__date', "#{formatted_date_for(complexity_add_time)} by #{pom_name.titleize}"],
          ].each do |key, val|
            expect(page).to have_css(key, text: val)
          end
        end
      end
    end
  end

  context 'with 2 history records' do
    let(:history) {
      [{ level: 'high',
         createdTimeStamp: complexity_add_time,
         sourceUser: username },
       { level: 'medium',
         createdTimeStamp: complexity_change_time,
         notes: reason,
         sourceUser: username }]
    }
    let(:reason) { 'There really must have been a reason' }

    it 'has 1 prison section' do
      expect(all('.govuk-grid-row').size).to eq(1)
    end

    it 'has 3 detail sections' do
      within '.govuk-grid-row:nth-of-type(1)' do
        expect(page).to have_css('.govuk-heading-m', text: prison.name)
        expect(all('.moj-timeline__item').size).to eq(3)
      end
    end

    it 'has a complexity change section', :js do
      within '.govuk-grid-row:nth-of-type(1)' do
        within '.moj-timeline__item:nth-of-type(1)' do
          expect(page).to have_css('.moj-timeline__title', text: 'Complexity of need level updated')
          expect(page).to have_css('.moj-timeline__description', text: [
            'Changed from: High to Medium',
            "Reason(s) for the change: #{reason}"
          ].join("\n"))
          expect(page).to have_css('.moj-timeline__date', text: "#{formatted_date_for(complexity_change_time)} by #{pom_name.titleize}")
        end
      end
    end
  end

  context 'with no history records', :js do
    let(:history) { [] }

    it 'has only 1 prison section' do
      expect(all('.govuk-grid-row').size).to eq(1)
    end

    it 'has 1 detail sections' do
      within '.govuk-grid-row:nth-of-type(1)' do
        expect(page).to have_css('.govuk-heading-m', text: prison.name)
        expect(all('.moj-timeline__item').size).to eq(1)
      end
    end
  end

  def formatted_date_for(updated_at)
    updated_at.strftime("#{updated_at.day.ordinalize} %B %Y") + " (" + updated_at.strftime("%R") + ")"
  end
end
