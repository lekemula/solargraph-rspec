# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      # Utility methods for working with RSpec AST nodes.
      # Provides both module-level functions (NodeTypes.method) and instance methods
      # when included. Also provides node pattern matchers via RuboCop::AST::NodePattern::Macros.
      # Config-dependent predicates (#let_block_method?, #example_block_method?)
      # must be defined by the includer.
      module NodeTypes
        extend RuboCop::AST::NodePattern::Macros

        BUILDER = RuboCop::AST::Builder.new
        private_constant :BUILDER

        # @!method block_method_name(node)
        #   @param node [RuboCop::AST::Node]
        #   @return [Symbol, nil]
        def_node_matcher :block_method_name, '(block (send _ $_ ...) ...)'

        # @!method context_description_node(node)
        #   @param node [RuboCop::AST::Node]
        #   @return [RuboCop::AST::Node, nil]
        def_node_matcher :context_description_node, '(block (send _ _ $_ ...) ...)'

        # @!method let_symbol_name(node)
        #   @param node [RuboCop::AST::Node]
        #   @return [Symbol, nil]
        def_node_matcher :let_symbol_name, '(block (send _ _ (sym $_)) ...)'

        module_function :block_method_name, :context_description_node, :let_symbol_name

        module_function

        # Converts a Parser::AST::Node tree to RuboCop::AST::Node using the
        # RuboCop::AST::Builder, preserving all source locations.
        # This is needed because NodePattern requires RuboCop::AST::Node.
        # @param node [::Parser::AST::Node, Object]
        # @return [RuboCop::AST::Node, Object]
        def to_rubocop_ast(node)
          return node unless node.is_a?(::Parser::AST::Node)
          return node if node.is_a?(::RuboCop::AST::Node)

          converted_children = node.children.map { |child| to_rubocop_ast(child) }
          BUILDER.n(node.type, converted_children, node.loc)
        end

        # @param method_name [Symbol, String]
        # @param config [Config]
        # @return [Boolean]
        def let_block_method?(method_name, config)
          config.let_methods.map(&:to_s).include?(method_name.to_s)
        end

        # @param method_name [Symbol, String]
        # @param config [Config]
        # @return [Boolean]
        def example_block_method?(method_name, config)
          config.example_methods.map(&:to_s).include?(method_name.to_s)
        end

        # @param block_ast [RuboCop::AST::Node]
        # @param config [Config]
        # @return [Boolean]
        def a_example_block?(block_ast, config)
          config.example_methods.map(&:to_s).include?(block_method_name(block_ast)&.to_s)
        end

        # @param ast [RuboCop::AST::Node]
        # @return [Boolean]
        def a_constant?(ast)
          ast.is_a?(::RuboCop::AST::Node) && ast.const_type?
        end

        def context_block_method?(method_name)
          Solargraph::Rspec::CONTEXT_METHODS.include?(method_name.to_s)
        end

        def subject_block_method?(method_name)
          Solargraph::Rspec::SUBJECT_METHODS.include?(method_name.to_s)
        end

        def hook_block_method?(method_name)
          Solargraph::Rspec::HOOK_METHODS.include?(method_name.to_s)
        end
      end
    end
  end
end
