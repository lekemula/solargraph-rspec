# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      class FakeLetMethod
        MATCH_DO_END = /.*? do(.*)end/m
        MATCH_CURLY = /{(.*)}/m

        class << self
          # Transforms let block to method ast node
          # @param block_ast [RubyVM::AbstractSyntaxTree::Node]
          # @param code [String] code
          # @return [::Parser::AST::Node, nil]
          def transform_block(block_ast, code, method_name = nil)
            method_name ||= NodeTypes.let_method_name(block_ast)

            code_lines = code.split("\n")
            # extract let definition block body code
            first_line = code_lines[block_ast.first_lineno - 1]
            last_line = code_lines[block_ast.last_lineno - 1]
            code_lines[block_ast.first_lineno - 1] = first_line[(block_ast.first_column)..]
            code_lines[block_ast.last_lineno - 1] = last_line[0..(block_ast.last_column)]
            let_definition_code = code_lines[
              (block_ast.first_lineno - 1)..(block_ast.last_lineno - 1)
            ].join("\n")

            let_definition_ast = Solargraph::Parser.parse(let_definition_code)
            method_body = let_definition_ast.children[2]
            ::Parser::AST::Node.new( # transform let block to a method ast node
              :def,
              [
                method_name.to_sym,
                ::Parser::AST::Node.new(:args, []),
                method_body
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
