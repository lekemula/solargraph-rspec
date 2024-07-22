# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in solargraph-rspec.gemspec
gemspec

# Development Dependencies
gem 'bundler'             # Dependency management
gem 'debug'               # Debugging
gem 'profile-viewer'      # View profile from Vernier
gem 'rake'                # Build
gem 'rspec'               # Testing
gem 'rubocop'             # Linting
gem 'simplecov'           # Code coverage
gem 'simplecov-cobertura' # Code coverage
# gem 'vernier'        # Profiling only on Ruby >= 3.2.1

group :third_party_plugin_tests do
  gem 'rspec-rails'
  gem 'actionmailer'
  gem 'shoulda-matchers'
  gem 'rspec-sidekiq'
end

# Debugging
# Use local solargraph repo for ease of debugging
# gem 'solargraph', path: '../solargraph'
