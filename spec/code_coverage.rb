# frozen_string_literal: true

# Code coverage
require 'simplecov' # Needs to be required first
require 'simplecov-cobertura'

SimpleCov.start do
  enable_coverage :branch
end

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
  [
    SimpleCov::Formatter::CoberturaFormatter,
    SimpleCov::Formatter::HTMLFormatter
  ]
)
