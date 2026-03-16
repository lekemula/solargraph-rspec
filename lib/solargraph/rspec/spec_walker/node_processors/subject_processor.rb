# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      module NodeProcessors
        # Processor for RSpec subject blocks.
        # Extracts subject method names (or uses 'subject' as default) and fires events with synthetic method ASTs.
        class SubjectProcessor < BaseProcessor
          on_node_pattern_enter '(block (send _ #subject_block_method? ...) ...)', :process_subject

          private

          # Extract subject method name and fire event with synthetic method AST.
          # @param node [RuboCop::AST::Node]
          # @return [void]
          def process_subject(node)
            method_name = let_symbol_name(node)&.to_s
            fake_ast = FakeLetMethod.transform_block(node, method_name || 'subject')
            fire(:on_subject, method_name, PinFactory.build_location_range(node.children[0]), fake_ast)
          end
        end
      end
    end
  end
end
