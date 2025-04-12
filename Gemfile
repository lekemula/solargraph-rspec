# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in solargraph-rspec.gemspec
gemspec

# TODO: Remove me after fixing specs till latest solargraph version
gem 'solargraph', '0.53.4'

# Development Dependencies
gem 'appraisal'           # Test against multiple versions of dependencies
gem 'bundler'             # Dependency management
gem 'debug'               # Debugging
gem 'profile-viewer'      # View profile from Vernier
gem 'pry-byebug'          # Debugging
gem 'rake'                # Build
gem 'rspec'               # Testing
gem 'rubocop'             # Linting
gem 'simplecov'           # Code coverage
gem 'simplecov-cobertura' # Code coverage
# gem 'vernier'             # Profiling only on Ruby >= 3.2.1

group :third_party_plugin_tests do
  gem 'actionmailer'
  gem 'airborne'
  gem 'rspec-rails'
  gem 'rspec-sidekiq'
  gem 'shoulda-matchers'
  gem 'webmock'
end

# Debugging
# Use local solargraph repo for ease of debugging
# gem 'solargraph', path: '../solargraph'
