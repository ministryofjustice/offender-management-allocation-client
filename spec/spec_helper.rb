require 'simplecov'
require 'simplecov-lcov'

# This allows both LCOV and HTML formatting -
# lcov for undercover gem and cc-test-reporter, HTML for humans
class SimpleCov::Formatter::MergedFormatter
  def format(result)
    SimpleCov::Formatter::HTMLFormatter.new.format(result)
    SimpleCov::Formatter::LcovFormatter.new.format(result)
  end
end

SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
# for cc-test-reporter after-build action
SimpleCov::Formatter::LcovFormatter.config.output_directory = 'coverage'
SimpleCov::Formatter::LcovFormatter.config.lcov_file_name = 'lcov.info'
SimpleCov.formatter = SimpleCov::Formatter::MergedFormatter

SimpleCov.start 'rails' do
  add_filter 'app/services/hmpps_api/error/'
  add_filter 'lib/allocation_validation.rb'
  add_filter 'app/jobs/custom_stats_logging_job.rb'
  add_filter 'app/admin/'
  add_group "Services", "app/services"

  # Try to set this to current coverage levels so that it never goes down after a PR
  # 5 lines uncovered at 99.85% coverage
  minimum_coverage 99.85
  # sometimes coverage drops between branches - don't fail in these cases
  maximum_coverage_drop 0.5

  # set merge_timeout to 30 minutes on circle:ci
  merge_timeout ENV['MERGE_TIMEOUT'].to_i if ENV['MERGE_TIMEOUT']
end

if ENV['CIRCLE_ARTIFACTS']
  dir = File.join(ENV['CIRCLE_ARTIFACTS'], "coverage")
  SimpleCov.coverage_dir(dir)
end

# patch to support SAMPLE=nn to only run nn tests
require "test_prof/recipes/rspec/sample"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end

require 'vcr'

# the default is :once, which seems to mess-up our cassette re-use
# set VCR=1 when you wish to record new interactions with T3 (hopefully never)
# set VCR=2 when the world changes dramatically e.g. new host, change API
RECORD_MODES = { 0 => :none, 1 => :new_episodes, 2 => :all }.freeze

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  # using this higher-level hook allows WebMock to write-out stub calls when not in VCR-mode
  config.hook_into :faraday
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = true
  # weirdly this assignment is implemented as a merge in VCR, so it only
  # overwrites the specified configuration options
  config.default_cassette_options = {
    record: RECORD_MODES.fetch(ENV.fetch('VCR', '0').to_i),
    match_requests_on: [
      :method,
      :uri,
      :body,
      :paging_headers
    ]
  }

  config.register_request_matcher :paging_headers do |r1, r2|
    paging_headers = %w[Page-Limit Page-Offset]

    r1_headers = r1.headers.select { |k, _| paging_headers.include?(k) }
    r2_headers = r2.headers.select { |k, _| paging_headers.include?(k) }

    r1_headers == r2_headers
  end

  config.filter_sensitive_data('authorisation_header') do |interaction|
    interaction.request.headers['Authorization']&.first
  end

  config.ignore_request do |request|
    # don't record auth requests as they clutter the recordings
    request.uri =~ /__identify__|session|auth/
  end
end
