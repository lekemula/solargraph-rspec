# rubocop:disable Naming/FileName
# frozen_string_literal: true

require 'solargraph'

require_relative 'solargraph/rspec/version'
require_relative 'solargraph/rspec/convention'

Solargraph::Convention.register Solargraph::Rspec::Convention
# rubocop:enable Naming/FileName
