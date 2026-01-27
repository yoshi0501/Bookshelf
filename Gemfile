source 'https://rubygems.org'

ruby '3.2.2'

# Rails 7
gem 'rails', '~> 7.1.0'

# Database
gem 'pg', '~> 1.5'

# Web Server
gem 'puma', '~> 6.0'

# Assets
gem 'sprockets-rails'
gem 'importmap-rails'
gem 'turbo-rails'
gem 'stimulus-rails'
gem 'tailwindcss-rails'

# JSON
gem 'jbuilder'

# Authentication
gem 'devise', '~> 4.9'

# Authorization
gem 'pundit', '~> 2.3'

# Audit Trail
gem 'paper_trail', '~> 15.1'

# Background Jobs (for future use)
gem 'sidekiq', '~> 7.0'

# Pagination
gem 'pagy', '~> 6.0'

# Environment Variables
gem 'dotenv-rails', groups: [:development, :test]

# Password validation
gem 'devise-security', '~> 0.18'

# 2FA (optional - for future implementation)
# gem 'devise-two-factor', '~> 5.0'

# CSV export
gem 'csv'

# Windows timezone data
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# Performance
gem 'bootsnap', require: false

group :development, :test do
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'rspec-rails', '~> 6.0'
  gem 'factory_bot_rails', '~> 6.2'
  gem 'faker', '~> 3.2'
end

group :development do
  gem 'web-console'
  gem 'annotate'
  gem 'rubocop-rails', require: false
end

group :test do
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'shoulda-matchers', '~> 5.0'
  gem 'database_cleaner-active_record'
end
