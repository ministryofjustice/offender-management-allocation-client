require 'rails_helper'

feature 'Search for offenders' do
  context 'with delius import on' do
    let(:test_strategy) { Flipflop::FeatureSet.current.test! }

    before do
      test_strategy.switch!(:auto_delius_import, true)
    end

    after do
      test_strategy.switch!(:auto_delius_import, false)
    end

    it 'shows update not edit', vcr: { cassette_name: :search_update_edit } do
      signin_user
      visit prison_summary_allocated_path('LEI')

      expect(page).to have_text('See allocations')
      fill_in 'q', with: 'G4273GI'
      click_on('search-button')

      update_link = find('td a')
      expect(update_link.text).to eq('Update')
      expect(page).to have_current_path(prison_search_path('LEI'), ignore_query: true)
    end
  end

  context 'with delius import off' do
    let(:test_strategy) { Flipflop::FeatureSet.current.test! }

    before do
      test_strategy.switch!(:auto_delius_import, false)
    end

    it 'shows update not edit', vcr: { cassette_name: :search_update_edit_no_delius } do
      signin_user
      visit prison_summary_allocated_path('LEI')

      expect(page).to have_text('See allocations')
      fill_in 'q', with: 'G4273GI'
      click_on('search-button')

      update_link = find('td a')
      expect(update_link.text).to eq('Edit')
      expect(page).to have_current_path(prison_search_path('LEI'), ignore_query: true)
    end
  end

  it 'Can search from the dashboard', vcr: { cassette_name: :dashboard_search_feature } do
    signin_user
    visit root_path

    expect(page).to have_text('Dashboard')
    fill_in 'q', with: 'Cal'
    click_on('search-button')

    expect(page).to have_current_path(prison_search_path('LEI'), ignore_query: true)
    expect(page).to have_css('tbody tr', count: 5)
  end

  it 'Can search from the Allocations summary page', vcr: { cassette_name: :allocated_search_feature } do
    signin_user
    visit prison_summary_allocated_path('LEI')

    expect(page).to have_text('See allocations')
    fill_in 'q', with: 'Fra'
    click_on('search-button')

    expect(page).to have_current_path(prison_search_path('LEI'), ignore_query: true)
    expect(page).to have_css('tbody tr', count: 9)
  end

  it 'Can search from the Awaiting Allocation summary page', vcr: { cassette_name: :waiting_allocation_search_feature } do
    signin_user
    visit prison_summary_unallocated_path('LEI')

    expect(page).to have_text('Make allocations')
    fill_in 'q', with: 'Tre'
    click_on('search-button')

    expect(page).to have_current_path(prison_search_path('LEI'), ignore_query: true)
    expect(page).to have_css('tbody tr', count: 1)
  end

  it 'Can search from the Missing Information summary page', vcr: { cassette_name: :missing_info_search_feature } do
    signin_user
    visit  prison_summary_pending_path('LEI')

    expect(page).to have_text('Make allocations')
    fill_in 'q', with: 'Ste'
    click_on('search-button')

    expect(page).to have_current_path(prison_search_path('LEI'), ignore_query: true)
    expect(page).to have_css('tbody tr', count: 4)
  end
end
