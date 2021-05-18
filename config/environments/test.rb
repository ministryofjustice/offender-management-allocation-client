# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!
Rails.application.configure do
  # Before filter for Flipflop dashboard. Replace with a lambda or method name
  # defined in ApplicationController to implement access control.
  # don't override this here - we want to test that we have implemented the access controls correctly
  # config.flipflop.dashboard_access_filter = nil

  # Settings specified here will take precedence over those in config/application.rb.
  config.notify_api_key = ENV['TEST_NOTIFY_API_KEY']
  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  config.action_controller.perform_caching = false
  config.active_job.queue_adapter = :inline

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false
  config.action_controller.action_on_unpermitted_parameters = :raise

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test
  # TODO: Ideally this should be enabled, but doing so makes
  # the circle:ci build fail due to a lack of a TEST_NOTIFY_API_KEY
  # combined with the fact that in Notify-land the ActionMailer::TestMailer
  # isn't actually used despite delivery_method being set to :test
  config.action_mailer.perform_deliveries = false
  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raises error for missing translations.
  # config.action_view.raise_on_missing_translations = true
  Rails.application.routes.default_url_options[:host] = 'http://localhost:3000'

  # It seems that the default cookie store behaves very subtly different to the cache store
  # (the cookie store implicitly serializes objects, where the cache store doesn't)
  # Since cache store is used in production, tests should really be running against the same session store
  # to replicate a production-like environment (especially important for feature tests)
  config.session_store :cache_store, key: 'manage_pom_cases_session'

  # ...which means we also need to use a proper cache store, rather than the default null store
  # To avoid leaking global state between tests, we clear this cache after every spec in rails_helper.rb
  config.cache_store = :memory_store, { size: 64.megabytes }

  # Has to be hard-coded here rather than an ENV as the VCR cassettes have this hostname in them.
  config.community_api_host = 'https://community-api.test.probation.service.justice.gov.uk'
end
