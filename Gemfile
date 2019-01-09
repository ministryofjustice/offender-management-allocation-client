source 'https://rubygems.org'
git_source(:github) do |repo| "https://github.com/#{repo}.git" end

ruby '2.5.3'

gem 'bootsnap', '>= 1.1.0', require: false
gem 'coffee-rails', '~> 4.2'
gem 'faraday'
gem 'jbuilder', '~> 2.8'
gem 'jwt'
gem 'lograge'
gem 'logstash-event'
gem 'omniauth-oauth2'
gem 'puma', '~> 3.11'
gem 'prometheus_exporter'
gem 'rails', '~> 5.2.2'
gem 'sass-rails', '~> 5.0'
gem 'sentry-raven'
gem 'turbolinks', '~> 5'
gem 'uglifier', '>= 1.3.0'
gem 'loaf'

group :development, :test do
  gem 'brakeman'
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'rubocop'
  gem 'rubocop-rspec'
end

group :test do
  gem 'capybara'
  gem 'rspec-rails'
  gem 'selenium-webdriver'
  gem 'simplecov'
  gem 'vcr'
  gem 'webmock'
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'web-console', '>= 3.3.0'
end

gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
