sentry_dsn = Rails.configuration.sentry_dsn
Sentry.init do |config|
  config.send_default_pii = true
  config.logger = Rails.logger
  config.breadcrumbs_logger = [:active_support_logger]
  if sentry_dsn
    config.dsn = sentry_dsn
  else
    Rails.logger.warn '[WARN] Sentry is not configured (SENTRY_DSN)' unless sentry_dsn
  end
  config.excluded_exceptions << 'JWT::ExpiredSignature'
  if ENV['HEROKU_BRANCH']
    config.environment = ENV.fetch('HEROKU_BRANCH')
  end

  # Filter out sensitive fields from sentry logs
  config.before_send = lambda { |event, _hint|
    #event.reject! { |key| Rails.application.config.filter_parameters.include?(key) }
    puts 'tags', event.tags.inspect, 'user', event.user.inspect, 'extra', event.extra.inspect
    #Rails.application.config.filter_parameters.each do |field|
    #  puts 'field', field, 'value', event[field]
    #  event[field] = nil if event[field].present?
    #end
    #puts "event", event.inspect, 'filter', Rails.application.config.filter_parameters.inspect
    event
  }
end
