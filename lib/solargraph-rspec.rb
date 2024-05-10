# rubocop:disable Naming/FileName
# frozen_string_literal: true

require 'solargraph'
require 'active_support'

require_relative 'solargraph/rspec/version'
require_relative 'solargraph/rspec/convention'

module Solargraph
  module Rspec
    class NodeParser
      extend Solargraph::Parser::Legacy::ClassMethods
    end
  end
end

Solargraph::Convention.register Solargraph::Rspec::Convention
# rubocop:enable Naming/FileName
