require 'simplecov'

SimpleCov.start 'rails' do
  add_filter 'app/services/nomis/error/'
  add_filter 'lib/allocation_validation.rb'
  add_filter 'app/jobs/custom_stats_logging_job.rb'
  add_group "Services", "app/services"

  # Try to set this to current coverage levels so that it never goes down after a PR
  # 22 lines uncovered at 99.24% coverage
  minimum_coverage 99.23
  # sometimes coverage drops between branches - don't fail in these cases
  maximum_coverage_drop 0.1
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

recording = ENV['VCR']

vcr_record_mode = recording ? :all : :none

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"

  if recording
    config.hook_into :webmock
  else
    config.hook_into :faraday
  end
  config.configure_rspec_metadata!
  # this allows HTTP connections to go through to webmock if cassette not specified
  config.allow_http_connections_when_no_cassette = true
  config.default_cassette_options = {
    record: vcr_record_mode,
    # not sure if we need this on or off - when we are doing the oauth2 interactions, it might repeat many times
    # allow_playback_repeats: true,
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
