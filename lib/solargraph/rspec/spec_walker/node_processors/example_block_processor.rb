# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      module NodeProcessors
        # Processor for RSpec example blocks (it, specify).
        # Fires events for examples and tracks example/hook nesting depth.
        class ExampleBlockProcessor < BaseProcessor
          EXAMPLE_BLOCK_PATTERN = '(block (send _ #example_block_method? ...) ...)'
          on_node_pattern_enter EXAMPLE_BLOCK_PATTERN, :enter_example_block
          on_node_pattern_leave EXAMPLE_BLOCK_PATTERN, :leave_example_block

          private

          # @param method_name [Symbol, String]
          # @return [Boolean]
          def example_block_method?(method_name)
            NodeTypes.example_block_method?(method_name, spec_walker.config)
          end

          # Handle entry into an example block, firing event and incrementing depth.
          # @param node [RuboCop::AST::Node]
          # @return [void]
          def enter_example_block(node)
            fire(:on_example_block, PinFactory.build_location_range(node))
            spec_walker.increment_example_depth!
          end

          # Handle departure from an example block, decrementing depth.
          # @param _node [RuboCop::AST::Node]
          # @return [void]
          def leave_example_block(_node)
            spec_walker.decrement_example_depth!
          end
        end
      end
    end
  end
end
