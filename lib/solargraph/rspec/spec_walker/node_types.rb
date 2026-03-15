# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      class NodeTypes
        BUILDER = RuboCop::AST::Builder.new
        private_constant :BUILDER

        BLOCK_METHOD_NAME = RuboCop::AST::NodePattern.new('(block (send _ $_ ...) ...)')
        CONTEXT_DESCRIPTION_ARG = RuboCop::AST::NodePattern.new('(block (send _ _ $_ ...) ...)')
        LET_SYMBOL_NAME = RuboCop::AST::NodePattern.new('(block (send _ _ (sym $_)) ...)')

        # Converts a Parser::AST::Node tree to RuboCop::AST::Node using the
        # RuboCop::AST::Builder, preserving all source locations.
        # This is needed because NodePattern requires RuboCop::AST::Node.
        # @param node [::Parser::AST::Node, Object]
        # @return [RuboCop::AST::Node, Object]
        def self.to_rubocop_ast(node)
          return node unless node.is_a?(::Parser::AST::Node)
          return node if node.is_a?(::RuboCop::AST::Node)

          converted_children = node.children.map { |child| to_rubocop_ast(child) }
          BUILDER.n(node.type, converted_children, node.loc)
        end

        # @param ast [RuboCop::AST::Node]
        # @return [Boolean]
        def self.a_block?(ast)
          ast.is_a?(::RuboCop::AST::Node) && ast.block_type?
        end

        # @param block_ast [RuboCop::AST::Node]
        # @return [Boolean]
        def self.a_context_block?(block_ast)
          Solargraph::Rspec::CONTEXT_METHODS.include?(method_with_block_name(block_ast))
        end

        # @param block_ast [RuboCop::AST::Node]
        # @return [Boolean]
        def self.a_subject_block?(block_ast)
          Solargraph::Rspec::SUBJECT_METHODS.include?(method_with_block_name(block_ast))
        end

        # @param block_ast [RuboCop::AST::Node]
        # @param config [Config]
        # @return [Boolean]
        def self.a_example_block?(block_ast, config)
          config.example_methods.map(&:to_s).include?(method_with_block_name(block_ast))
        end

        # @param block_ast [RuboCop::AST::Node]
        # @param config [Config]
        # @return [Boolean]
        def self.a_let_block?(block_ast, config)
          config.let_methods.map(&:to_s).include?(method_with_block_name(block_ast))
        end

        # @param block_ast [RuboCop::AST::Node]
        # @return [Boolean]
        def self.a_hook_block?(block_ast)
          Solargraph::Rspec::HOOK_METHODS.include?(method_with_block_name(block_ast))
        end

        # @param ast [RuboCop::AST::Node]
        # @return [Boolean]
        def self.a_constant?(ast)
          ast.is_a?(::RuboCop::AST::Node) && ast.const_type?
        end

        # @param block_ast [RuboCop::AST::Node]
        # @return [String, nil] the name of the method called with the block
        def self.method_with_block_name(block_ast)
          BLOCK_METHOD_NAME.match(block_ast)&.to_s
        end

        # @param block_ast [RuboCop::AST::Node]
        # @return [RuboCop::AST::Node, nil]
        def self.context_description_node(block_ast)
          return nil unless a_context_block?(block_ast)

          CONTEXT_DESCRIPTION_ARG.match(block_ast)
        end

        # @param block_ast [RuboCop::AST::Node]
        # @return [String, nil]
        def self.let_method_name(block_ast)
          return nil unless a_block?(block_ast)

          LET_SYMBOL_NAME.match(block_ast)&.to_s
        end
      end
    end
  end
end
