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

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OffenderManagementAllocationClient
  class Application < Rails::Application
    # Disable CSS compression to enable SASSC support
    config.assets.css_compressor = nil

    # allow customization of full error messages on a per-model basis
    config.active_model.i18n_customize_full_message = true
    # Before filter for Flipflop dashboard. Replace with a lambda or method name
    # defined in ApplicationController to implement access control.
    config.flipflop.dashboard_access_filter = :ensure_admin_user

    config.load_defaults 6.0
    config.exceptions_app = routes
    config.generators.system_tests = nil
    config.active_job.queue_adapter = :sidekiq
    config.allocation_manager_host =
      ENV.fetch(
        'ALLOCATION_MANAGER_HOST',
        'http://localhost:3000'
  )
    Rails.application.routes.default_url_options[:host] =
      if ENV['HEROKU_APP_NAME'].present?
        ENV.fetch('HEROKU_APP_NAME') + '.herokuapp.com'
      else
        ENV.fetch(
          'ALLOCATION_MANAGER_HOST',
          'http://localhost:3000'
        )
      end

    # Sentry environment set with SENTRY_CURRENT_ENV
    config.sentry_dsn = ENV['SENTRY_DSN']&.strip

    config.keyworker_api_host = ENV['KEYWORKER_API_HOST']&.strip
    config.digital_prison_service_host = ENV['DIGITAL_PRISON_SERVICE_HOST']&.strip
    config.nomis_oauth_host = ENV['NOMIS_OAUTH_HOST']&.strip
    config.prison_api_host = ENV['PRISON_API_HOST']&.strip
    config.prisoner_search_host = ENV['PRISONER_SEARCH_HOST']&.strip
    config.complexity_api_host = ENV['COMPLEXITY_API_HOST']&.strip

    config.nomis_oauth_client_id = ENV['NOMIS_OAUTH_CLIENT_ID']&.strip
    config.nomis_oauth_client_secret = ENV['NOMIS_OAUTH_CLIENT_SECRET']&.strip
    config.nomis_oauth_public_key = ENV['NOMIS_OAUTH_PUBLIC_KEY']&.strip
    config.collect_prometheus_metrics = ENV['PROMETHEUS_METRICS']&.strip == 'on'
    config.ga_tracking_id = ENV['GA_TRACKING_ID']&.strip
    config.support_email = ENV['SUPPORT_EMAIL']&.strip
    config.redis_url = ENV['REDIS_URL']&.strip
    config.redis_auth = ENV['REDIS_AUTH']&.strip
    config.zendesk_token = ENV['ZENDESK_TOKEN']&.strip
    config.zendesk_password = ENV['ZENDESK_PASSWORD']&.strip
    config.zendesk_url = ENV['ZENDESK_URL']&.strip
    config.zendesk_username = ENV['ZENDESK_USERNAME']&.strip
    config.connection_pool_size = ENV['RAILS_WEB_CONCURRENCY']&.strip || 5
    config.zendesk_enabled =
      [config.zendesk_username, config.zendesk_url, config.zendesk_password].all?

    config.cache_expiry = (ENV['CACHE_TIMEOUT']&.strip || 60.minutes).to_i

    config.time_zone = 'London'

    # overriding the normal wrapping in a div with class 'field-with-errors' seems to be
    # neccesary in this project, otherwise Gov Design system check-boxes and radio buttons
    # don't 'check' visibly to the user even though they pass all the tests.
    config.action_view.field_error_proc = proc { |html_tag, _instance|
      html_tag
    }
  end
end
