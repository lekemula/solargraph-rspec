# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      class FakeLetMethod
        MATCH_DO_END = /.*? do(.*)end/m.freeze
        MATCH_CURLY = /{(.*)}/m.freeze

        class << self
          # Transforms let block to method ast node
          # @param block_ast [RubyVM::AbstractSyntaxTree::Node]
          # @return [RubyVM::AbstractSyntaxTree::Node, ::Parser::AST::Node, nil]
          def transform_block(block_ast, code, method_name = nil)
            method_name ||= NodeTypes.let_method_name(block_ast)

            if Solargraph::Parser.rubyvm?
              rubyvm_transform_block(block_ast, code, method_name)
            else
              parser_transform_block(block_ast, code, method_name)
            end
          end

          private

          # @param block_ast [RubyVM::AbstractSyntaxTree::Node]
          # @return [RubyVM::AbstractSyntaxTree::Node, nil]
          def rubyvm_transform_block(block_ast, code, method_name = nil)
            block_body = block_ast.children[1]
            let_definition_code = code.lines[block_body.first_lineno - 1..block_body.last_lineno - 1].join
            match_do_end = let_definition_code.match(MATCH_DO_END)&.captures&.first || ''
            match_curly = let_definition_code.match(MATCH_CURLY)&.captures&.first || ''
            method_body = [match_do_end, match_curly].max_by(&:length).strip

            ast = RubyVM::AbstractSyntaxTree.parse <<~RUBY
              def #{method_name}
                #{method_body}
              end
            RUBY

            ast.children[2]
          rescue SyntaxError => e
            Solargraph.logger.warn "[RSpec] Failed to build fake let method: #{e.message}, \
            \n\nlet_definition_code: \n```\n#{let_definition_code}\n```, \
            \n\nmethod_body: \n```\n#{method_body}\n```, \
            \nast: #{block_ast.inspect}"
          end

          # @param block_ast [RubyVM::AbstractSyntaxTree::Node]
          # @return [::Parser::AST::Node]
          def parser_transform_block(block_ast, code, method_name = nil)
            code_lines = code.split("\n")
            # extract let definition block body code
            first_line = code_lines[block_ast.first_lineno - 1]
            last_line = code_lines[block_ast.last_lineno - 1]
            code_lines[block_ast.first_lineno - 1] = first_line[(block_ast.first_column)..]
            code_lines[block_ast.last_lineno - 1] = last_line[0..(block_ast.last_column)]
            let_definition_code = code_lines[
              (block_ast.first_lineno - 1)..(block_ast.last_lineno - 1)
            ].join("\n")

            let_definition_ast = ::Parser::CurrentRuby.parse(let_definition_code)
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
