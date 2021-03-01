Rails.application.configure do
  # Before filter for Flipflop dashboard. Replace with a lambda or method name
  # defined in ApplicationController to implement access control.
  config.flipflop.dashboard_access_filter = nil

  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store, { size: 64.megabytes }
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  config.action_controller.action_on_unpermitted_parameters = :raise

  # This setting can be useful if you want jobs to run locally
  # config.active_job.queue_adapter = :inline

  # Don't care if the mailer can't send.
  config.notify_api_key = ENV['DEV_NOTIFY_API_KEY']
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  # In this app it adds about 1 second to request processing time
  config.assets.debug = false

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Raises error for missing translations.
  # config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
end

Rack::MiniProfiler.config.storage = Rack::MiniProfiler::MemoryStore
