# frozen_string_literal: true

require_relative 'base'

# A corrector that walks through RSpec AST nodes and corrects them
module Solargraph
  module Rspec
    module Correctors
      # A corrector of RSpec parsed pins by Solargraph
      # @abstract
      class WalkerBase < Base
        # @return [Array<Solargraph::Pin::Namespace>]
        attr_reader :namespace_pins

        # @return [Solargraph::Rspec::SpecWalker]
        attr_reader :rspec_walker

        # @param namespace_pins [Array<Solargraph::Pin::Base>]
        # @param rspec_walker [Solargraph::Rspec::SpecWalker]
        def initialize(namespace_pins:, rspec_walker:)
          super(namespace_pins: namespace_pins)
          @rspec_walker = rspec_walker
        end
      end
    end
  end
end
