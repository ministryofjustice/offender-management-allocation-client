# frozen_string_literal: true

namespace :integration_tests do
  TEST_USERNAME = 'Moic Integration-tests'

  desc 'Clean up allocations created by staging integration tests'
  task clean_up: :environment do
    if defined?(Rails) && Rails.env.development?
      Rails.logger = Logger.new(STDOUT)
    end

    Rails.logger.info 'Deleting integration test data'

    ids = AllocationHistory.where(
      created_by_name: TEST_USERNAME).
        pluck(:nomis_offender_id)
    cases = CaseInformation.where(nomis_offender_id: ids)
    cases.destroy_all

    AllocationHistory.where(created_by_name: TEST_USERNAME).destroy_all
  end
end
