require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'action_cable/engine'
require 'sprockets/railtie'

Bundler.require(*Rails.groups)

module OffenderManagementAllocationClient
  class Application < Rails::Application
    config.load_defaults 5.2
    config.exceptions_app = routes
    config.generators.system_tests = nil
    config.active_job.queue_adapter = :sidekiq
    config.allocation_manager_host = ENV.fetch(
      'ALLOCATION_MANAGER_HOST',
      'http://localhost:3000'
    )
    Rails.application.routes.default_url_options[:host] = ENV.fetch(
      'ALLOCATION_MANAGER_HOST',
      'http://localhost:3000'
    )
    config.sentry_dsn = ENV['SENTRY_DSN']
    config.keyworker_api_host = ENV['KEYWORKER_API_HOST']
    config.nomis_oauth_host = ENV['NOMIS_OAUTH_HOST']
    config.nomis_oauth_client_id = ENV['NOMIS_OAUTH_CLIENT_ID']
    config.nomis_oauth_client_secret = ENV['NOMIS_OAUTH_CLIENT_SECRET']
    config.nomis_oauth_public_key = ENV['NOMIS_OAUTH_PUBLIC_KEY']
    config.prometheus_metrics = ENV['PROMETHEUS_METRICS']
    config.ga_tracking_id = ENV['GA_TRACKING_ID']
    config.support_email = ENV['SUPPORT_EMAIL']
    config.redis_url = ENV['REDIS_URL']
    config.redis_auth = ENV['REDIS_AUTH']
  end
end
