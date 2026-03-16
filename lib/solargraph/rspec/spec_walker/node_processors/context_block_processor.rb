# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      module NodeProcessors
        # Processor for RSpec context blocks (describe, context).
        # Manages namespace stack and fires events for context blocks and described classes.
        class ContextBlockProcessor < BaseProcessor
          CONTEXT_BLOCK_PATTERN = '(block (send _ #context_block_method? ...) ...)'

          on_node_pattern_enter CONTEXT_BLOCK_PATTERN, :enter_context_block
          on_node_pattern_leave CONTEXT_BLOCK_PATTERN, :leave_context_block

          private

          # Handle entry into a context block, updating namespace stack and firing events.
          # @param node [RuboCop::AST::Node]
          # @return [void]
          def enter_context_block(node)
            block_name = RspecContextNamespace.from_block_ast(node)
            return unless block_name

            @pushed_nodes ||= []
            @pushed_nodes << node.object_id

            parent = spec_walker.namespace_stack.last
            block_name = "Test#{block_name}" if parent == Rspec::ROOT_NAMESPACE
            namespace_name = "#{parent}::#{block_name}"
            spec_walker.namespace_stack.push(namespace_name)

            fire(:on_each_context_block, namespace_name, PinFactory.build_location_range(node))

            desc_node = context_description_node(node)
            return unless desc_node&.const_type?

            fire(:on_described_class, FullConstantName.from_ast(desc_node), PinFactory.build_location_range(desc_node))
          end

          # Handle departure from a context block, popping namespace stack.
          # @param node [RuboCop::AST::Node]
          # @return [void]
          def leave_context_block(node)
            @pushed_nodes ||= []
            return unless @pushed_nodes.delete(node.object_id)

            spec_walker.namespace_stack.pop
          end
        end
      end
    end
  end
end
