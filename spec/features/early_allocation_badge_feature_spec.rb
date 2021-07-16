# frozen_string_literal: true

require 'rails_helper'

feature 'early allocation badges' do
  let(:prison) { create(:prison) }
  let(:nomis_offender) {
    build(:nomis_offender, agencyId: prison.code,
                               sentence: attributes_for(:sentence_detail,
                                                        conditionalReleaseDate: release_date,
                                                        sentenceStartDate: sentence_start))
  }
  let(:offender_no) { nomis_offender.fetch(:offenderNo) }
  let(:notes_badge) { 'EARLY ALLOCATION ASSESSMENT SAVED' }
  let(:active_badge) { 'EARLY ALLOCATION DECISION PENDING' }
  let(:approved_badge) { 'EARLY ALLOCATION ELIGIBLE' }

  before do
    signin_spo_user([prison.code])

    stub_auth_token
    stub_user(staff_id: 1234)
    stub_keyworker(prison.code, offender_no, build(:keyworker))
    stub_offender nomis_offender

    create(:case_information,
           offender: build(:offender, nomis_offender_id: offender_no,
           early_allocations: [early_allocation]))
    visit prison_prisoner_path(prison.code, offender_no)
  end

  context 'when pre-window' do
    let(:release_date) { Time.zone.today + 19.months }

    context 'with a current sentence' do
      let(:sentence_start) { Time.zone.today - 1.week }
      let(:allocation_date) { Time.zone.today }

      context 'when in flight (not really)' do
        let(:early_allocation) { build(:early_allocation, :pre_window, :discretionary, created_at: allocation_date) }

        it 'shows the right badge' do
          expect(page).to have_content notes_badge
        end
      end

      context 'when automatic' do
        let(:early_allocation) { build(:early_allocation, :pre_window, :eligible, created_at: allocation_date) }

        it 'shows the right badge' do
          expect(page).to have_content notes_badge
        end
      end
    end

    context 'with a previous sentence' do
      let(:sentence_start) { Time.zone.today - 1.week }
      let(:allocation_date) { Time.zone.today - 2.weeks }

      context 'when in flight (not really)' do
        let(:early_allocation) { build(:early_allocation, :pre_window, :discretionary, created_at: allocation_date) }

        it 'doesnt show a badge' do
          expect(page).not_to have_content notes_badge
        end
      end

      context 'when automatic' do
        let(:early_allocation) { build(:early_allocation, :pre_window, :eligible, created_at: allocation_date) }

        it 'doesnt show a badge' do
          expect(page).not_to have_content notes_badge
        end
      end
    end
  end

  context 'when within window' do
    let(:release_date) { Time.zone.today + 17.months }

    context 'with current sentence' do
      #sentence start date come before the allocation date
      let(:sentence_start) { Time.zone.today - 1.week }
      let(:allocation_date) { Time.zone.today }

      context 'when declined' do
        let(:early_allocation) { build(:early_allocation, :discretionary_declined, created_at: allocation_date) }

        it 'shows notes' do
          expect(page).to have_content notes_badge
        end
      end

      context 'when in flight' do
        let(:early_allocation) { build(:early_allocation, :discretionary, created_at: allocation_date) }

        it 'shows active' do
          expect(page).to have_content active_badge
        end
      end

      context 'when approved' do
        let(:early_allocation) { build(:early_allocation, :discretionary_accepted, created_at: allocation_date) }

        it 'shows approved' do
          expect(page).to have_content approved_badge
        end
      end

      context 'when automatic' do
        let(:early_allocation) { build(:early_allocation, :eligible, created_at: allocation_date) }

        it 'shows approved' do
          expect(page).to have_content approved_badge
        end
      end
    end

    context 'with a previous sentence' do
      # sentence start date comes after the allocation date
      let(:sentence_start) { Time.zone.today - 1.week }
      let(:allocation_date) { Time.zone.today - 2.weeks }

      context 'when declined' do
        let(:early_allocation) { build(:early_allocation, :discretionary_declined, created_at: allocation_date) }

        it 'doesnt display a badge' do
          expect(page).not_to have_content notes_badge
        end
      end

      context 'when in flight' do
        let(:early_allocation) { build(:early_allocation, :discretionary, created_at: allocation_date) }

        it 'doesnt display a badge' do
          expect(page).not_to have_content active_badge
        end
      end

      context 'when approved' do
        let(:early_allocation) { build(:early_allocation, :discretionary_accepted, created_at: allocation_date) }

        it 'doesnt display a badge' do
          expect(page).not_to have_content approved_badge
        end
      end

      context 'when automatic' do
        let(:early_allocation) { build(:early_allocation, :eligible, created_at: allocation_date) }

        it 'doesnt display a badge' do
          expect(page).not_to have_content notes_badge
        end
      end
    end
  end
end
