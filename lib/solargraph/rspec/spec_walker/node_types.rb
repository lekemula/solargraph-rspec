# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      class NodeTypes
        # @param ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [Boolean]
        def self.a_block?(ast)
          return false unless ast.is_a?(RubyVM::AbstractSyntaxTree::Node)

          %i[ITER LAMBDA].include?(ast.type)
        end

        # @param ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [Boolean]
        def self.a_context_block?(block_ast)
          Solargraph::Rspec::CONTEXT_METHODS.include?(method_with_block_name(block_ast))
        end

        # @param ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [Boolean]
        def self.a_subject_block?(block_ast)
          Solargraph::Rspec::SUBJECT_METHODS.include?(method_with_block_name(block_ast))
        end

        # @param ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [Boolean]
        def self.a_example_block?(block_ast)
          Solargraph::Rspec::EXAMPLE_METHODS.include?(method_with_block_name(block_ast))
        end

        # @param ast [RubyVM::AbstractSyntaxTree::Node]
        # @param config [Config]
        # @return [Boolean]
        def self.a_let_block?(block_ast, config)
          config.let_methods.map(&:to_s).include?(method_with_block_name(block_ast))
        end

        # @param ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [Boolean]
        def self.a_hook_block?(block_ast)
          Solargraph::Rspec::HOOK_METHODS.include?(method_with_block_name(block_ast))
        end

        def self.a_constant?(ast)
          %i[CONST COLON2].include?(ast.type)
        end

        # @param block_ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [String, nil]
        def self.method_with_block_name(block_ast)
          return nil unless a_block?(block_ast)

          method_call = %i[CALL FCALL].include?(block_ast.children[0].type)
          return nil unless method_call

          block_ast.children[0].children.select { |child| child.is_a?(Symbol) }.first&.to_s
        end

        # @param block_ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [RubyVM::AbstractSyntaxTree::Node]
        def self.context_description_node(block_ast)
          case block_ast.children[0].type
          when :CALL # RSpec.describe "something" do end
            block_ast.children[0].children[2].children[0]
          when :FCALL # describe "something" do end
            block_ast.children[0].children[1].children[0]
          end
        end

        # @param block_ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [String]
        def self.let_method_name(block_ast)
          block_ast.children[0].children[1]&.children&.[](0)&.children&.[](0)&.to_s
        end
      end
    end
  end
end
