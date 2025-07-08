# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      class FakeLetMethod
        MATCH_DO_END = /.*? do(.*)end/m
        MATCH_CURLY = /{(.*)}/m

        class << self
          # Transforms let block to method ast node
          # @param block_ast [::Parser::AST::Node]
          # @return [::Parser::AST::Node, nil]
          def transform_block(block_ast, method_name = nil)
            method_name ||= NodeTypes.let_method_name(block_ast)

            ::Parser::AST::Node.new( # transform let block to a method ast node
              :def,
              [
                method_name.to_sym,
                ::Parser::AST::Node.new(:args, []),
                block_ast.children[2]
              ]
            )
          rescue SyntaxError => e
            Solargraph.logger.warn "[RSpec] Failed to build fake let method: #{e.message}, \
            \n\nlet_definition_code: \n```\n#{let_definition_code}\n```, \
            \n\nmethod_body: \n```\n#{method_body}\n```, \
            \nast: #{block_ast.inspect}"
          end
        end
      end
    end
  end
end
