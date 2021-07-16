source 'https://rubygems.org'
git_source(:github) do |repo| "https://github.com/#{repo}.git" end

ruby '2.6.6'

gem 'auto_strip_attributes'
# Need AWS SNS SDK for publishing events to HMPPS_DOMAIN_EVENTS
gem 'aws-sdk-sns'
gem 'bootsnap', '>= 1.1.0', require: false
gem 'coffee-rails', '~> 5.0'
gem 'date_validator'
gem 'faraday', '~> 1.0'
gem 'govuk_notify_rails'
# we need the extra is_csv parameter available in 5.2 and above
gem 'notifications-ruby-client', '>= 5.2'
gem 'govuk_design_system_formbuilder', '~> 2.5'
gem 'jbuilder', '~> 2.11'
gem 'jsonb_accessor'
gem 'jwt'
gem 'lograge'
gem 'logstash-event'
# to enable custom log stats by writing logs directly
gem 'logstash-logger'
gem 'omniauth-oauth2'
gem 'paper_trail'
gem 'pg'
gem 'puma', '~> 5.3'
gem 'prometheus_exporter'
gem 'rails', '~> 6.0', '< 6.1'
gem 'sidekiq', '>= 6.1.2'
gem 'sentry-raven'
gem 'turbolinks', '~> 5'
gem 'uglifier', '>= 1.3.0'
gem 'typhoeus'
gem 'redis'
gem 'fast_underscore', require: false
gem 'flipflop'
gem 'hashdiff', ['>= 1.0.0.beta1', '< 2.0.0']
gem 'rubyzip'
gem 'turnout'
gem 'kaminari' # pagination
gem 'prawn-rails'
gem 'rswag-api' # api-documentation
gem 'rswag-ui'  # api-documentation interface
gem 'sassc-rails'
# simple validation of email addresses.
# ministryofjustice/email_address_validation thinks Faker emails don't parse which is annoying,
# whilst also allowing invalid emails through.
# https://stackoverflow.com/questions/38611405/email-validation-in-ruby-on-rails
gem 'valid_email2'
gem 'wicked'
gem 'zendesk_api'

gem 'activeadmin'

group :development, :test do
  gem 'brakeman'
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'dotenv-rails'
  gem 'factory_bot_rails'
  gem 'parallel_tests'
  gem 'rubocop'
  gem 'rubocop-rspec', '>= 1.41'
  gem 'rubocop-performance'
  gem 'rubocop-rails'
  gem 'rubocop-govuk'
  # needed to support Rails 6.0
  gem 'rspec-rails', '~> 4.0'
  gem 'rswag-specs'
  gem 'spring'
  gem 'undercover'
end

group :test do
  gem 'capybara'
  gem 'database_cleaner-active_record'
  gem 'faker'
  gem 'launchy'
  gem 'rails-controller-testing'
  gem 'ruby-prof', '>= 0.16.0', require: false
  gem 'selenium-webdriver'
  gem 'shoulda-matchers'
  gem 'simplecov'
  # we can't use the branch coverage version of simplecov, (due to code climate)
  # and it seems that simplecov-lcov doesn't correctly depend on the branch coverage version of simplecov
  gem 'simplecov-lcov', '< 0.9'
  # https://evilmartians.com/chronicles/testprof-a-good-doctor-for-slow-ruby-tests
  gem 'test-prof'
  gem 'timecop'
  gem 'vcr'
  gem 'webmock'
end

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'flamegraph'
  gem 'guard-rspec'
  gem 'guard-rubocop'
  gem 'listen', '>= 3.0.5', '< 3.3'
  gem 'memory_profiler'
  # prevent warnings from parser as we are using ruby 2.6
  # change this when upgrading ruby version
  gem 'parser', '< 3.1'
  gem 'rack-mini-profiler'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'stackprof'
end

gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
