# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      module NodeProcessors
        # Processor for RSpec let blocks.
        # Extracts let method names and fires events with synthetic method ASTs for type inference.
        class LetMethodProcessor < BaseProcessor
          on_node_pattern_enter '(block (send _ #let_block_method? ...) ...)', :process_let_method

          private

          # @param method_name [Symbol, String]
          # @return [Boolean]
          def let_block_method?(method_name)
            NodeTypes.let_block_method?(method_name, spec_walker.config)
          end

          # Extract let method name and fire event with synthetic method AST.
          # @param node [RuboCop::AST::Node]
          # @return [void]
          def process_let_method(node)
            method_name = let_symbol_name(node)&.to_s
            return unless method_name

            fake_ast = FakeLetMethod.transform_block(node, method_name)
            fire(:on_let_method, method_name, PinFactory.build_location_range(node.children[0]), fake_ast)
          end
        end
      end
    end
  end
end
