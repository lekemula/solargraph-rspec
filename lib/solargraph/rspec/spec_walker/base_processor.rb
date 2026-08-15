# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      # Base class for all RSpec-specific node processors.
      # Extends Walker::BaseProcessor with NodeTypes matchers and RSpec walker access.
      class BaseProcessor < Walker::BaseProcessor
        include NodeTypes

        private

        # @return [SpecWalker, nil]
        def spec_walker
          walker.context[:rspec_walker]
        end

        # Fire an event on the spec walker.
        # @param event [Symbol]
        # @param args [Array] Arguments to pass with the event
        # @return [void]
        def fire(event, *args)
          spec_walker.fire(event, *args)
        end
      end
    end
  end
end
