# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      class NodeTypes
        # @param ast [::Parser::AST::Node]
        # @return [Boolean]
        def self.a_block?(ast)
          ast.is_a?(::Parser::AST::Node) && ast.type == :block
        end

        # @param block_ast [::Parser::AST::Node]
        # @return [Boolean]
        def self.a_context_block?(block_ast)
          Solargraph::Rspec::CONTEXT_METHODS.include?(method_with_block_name(block_ast))
        end

        # @param block_ast [::Parser::AST::Node]
        # @return [Boolean]
        def self.a_subject_block?(block_ast)
          Solargraph::Rspec::SUBJECT_METHODS.include?(method_with_block_name(block_ast))
        end

        # @param block_ast [::Parser::AST::Node]
        # @param config [Config]
        # @return [Boolean]
        def self.a_example_block?(block_ast, config)
          config.example_methods.map(&:to_s).include?(method_with_block_name(block_ast))
        end

        # @param block_ast [::Parser::AST::Node]
        # @param config [Config]
        # @return [Boolean]
        def self.a_let_block?(block_ast, config)
          config.let_methods.map(&:to_s).include?(method_with_block_name(block_ast))
        end

        # @param block_ast [::Parser::AST::Node]
        # @return [Boolean]
        def self.a_hook_block?(block_ast)
          Solargraph::Rspec::HOOK_METHODS.include?(method_with_block_name(block_ast))
        end

        # @param [::Parser::AST::Node] ast
        # @return [Boolean]
        def self.a_constant?(ast)
          ast.type == :const
        end

        # @param block_ast [::Parser::AST::Node]
        # @return [String, nil] The name of the thing you are calling the block on
        def self.method_with_block_name(block_ast)
          return nil unless a_block?(block_ast)
          return nil unless block_ast.children[0].type == :send

          block_ast.children[0].children[1].to_s
        end

        # @param block_ast [::Parser::AST::Node]
        # @return [::Parser::AST::Node, nil]
        def self.context_description_node(block_ast)
          return nil unless a_context_block?(block_ast)

          block_ast.children[0].children[2]
        end

        # @param block_ast [::Parser::AST::Node]
        # @return [String, nil]
        def self.let_method_name(block_ast)
          return nil unless a_block?(block_ast)

          block_ast.children[0].children[2]&.children&.[](0)&.to_s # rubocop:disable Style/SafeNavigationChainLength
        end

        # @param block_ast [::Parser::AST::Node]
        # @return [Boolean]
        def self.a_shared_example_definition?(block_ast)
          SHARED_EXAMPLE_DEFINITION_METHODS.include?(method_with_block_name(block_ast))
        end

        # @param block_ast [::Parser::AST::Node]
        # @return [String, Symbol, nil] The name of the shared example being defined or included
        def self.shared_example_name(block_ast)
          return nil unless a_shared_example_definition?(block_ast)

          name_node = block_ast.children[0].children[2]
          return nil unless name_node

          case name_node.type
          when :str, :dstr
            name_node.children[0]&.to_s
          when :sym
            name_node.children[0]
          end
        end
      end
    end
  end
end
