# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      module NodeProcessors
        # Processor for RSpec hook blocks (before, after, around).
        # Fires events for hooks and tracks example/hook nesting depth.
        class HookBlockProcessor < BaseProcessor
          HOOK_BLOCK_PATTERN = '(block (send _ #hook_block_method? ...) ...)'

          on_node_pattern_enter HOOK_BLOCK_PATTERN, :enter_hook_block
          on_node_pattern_leave HOOK_BLOCK_PATTERN, :leave_hook_block

          private

          # Handle entry into a hook block, firing event and incrementing depth.
          # @param node [RuboCop::AST::Node]
          # @return [void]
          def enter_hook_block(node)
            fire(:on_hook_block, PinFactory.build_location_range(node))
            spec_walker.increment_example_depth!
          end

          # Handle departure from a hook block, decrementing depth.
          # @param _node [RuboCop::AST::Node]
          # @return [void]
          def leave_hook_block(_node)
            spec_walker.decrement_example_depth!
          end
        end
      end
    end
  end
end
