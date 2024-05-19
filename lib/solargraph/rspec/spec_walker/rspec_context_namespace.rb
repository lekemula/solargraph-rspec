# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      class RspecContextNamespace
        class << self
          # @param block_ast [RubyVM::AbstractSyntaxTree::Node]
          # @return [String, nil]
          def from_block_ast(block_ast)
            return unless block_ast.is_a?(RubyVM::AbstractSyntaxTree::Node)

            ast = NodeTypes.context_description_node(block_ast)
            if ast.type == :STR
              string_to_const_name(ast)
            elsif NodeTypes.a_constant?(ast)
              FullConstantName.from_ast(ast).gsub('::', '')
            else
              Solargraph.logger.warn "[RSpec] Unexpected AST type #{ast.type}"
              nil
            end
          end

          private

          # @see https://github.com/rspec/rspec-core/blob/1eeadce5aa7137ead054783c31ff35cbfe9d07cc/lib/rspec/core/example_group.rb#L862
          # @param ast [Parser::AST::Node]
          # @return [String]
          def string_to_const_name(string_ast)
            return unless string_ast.type == :STR

            name = string_ast.children[0]
            return 'Anonymous'.dup if name.empty?

            # Convert to CamelCase.
            name = +" #{name}"
            name.gsub!(/[^0-9a-zA-Z]+([0-9a-zA-Z])/) do
              match = ::Regexp.last_match[1]
              match.upcase!
              match
            end

            name.lstrip! # Remove leading whitespace
            name.gsub!(/\W/, '') # JRuby, RBX and others don't like non-ascii in const names

            # Ruby requires first const letter to be A-Z. Use `Nested`
            # as necessary to enforce that.
            name.gsub!(/\A([^A-Z]|\z)/, 'Nested\1')

            name
          end
        end
      end
    end
  end
end
