# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      module NodeProcessors
        # Processor that identifies and fires events for blocks within RSpec examples or hooks.
        # Fires on_blocks_in_examples for any block node found inside an example or hook block.
        class BlocksInExamplesProcessor < BaseProcessor
          on_node_type :block, :process_block

          private

          # Fire event for blocks found within example or hook blocks.
          # @param node [RuboCop::AST::Node]
          # @return [void]
          def process_block(node)
            return unless spec_walker.in_example_or_hook?

            fire(:on_blocks_in_examples, PinFactory.build_location_range(node))
          end
        end
      end
    end
  end
end
