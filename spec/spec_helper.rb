# frozen_string_literal: true

require 'solargraph-rspec'
require 'debug'

ENV['SOLARGRAPH_DEBUG'] ||= 'true'

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  config.include SolargraphHelpers
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.exclude_pattern = 'spec/fixtures/**/*'

  config.filter_run_when_matching :focus
end
