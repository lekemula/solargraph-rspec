# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      class FullConstantName
        class << self
          # @param ast [::Parser::AST::Node]
          # @return [String]
          def from_ast(ast)
            parts = []

            until ast.nil?
              if ast.is_a? ::Parser::AST::Node
                break unless ast.type == :const

                parts << ast.children[1]
                ast = ast.children[0]
              else
                parts << ast
                break
              end
            end

            parts.reverse.join('::')
          end

          def from_context_block_ast(block_ast)
            ast = NodeTypes.context_description_node(block_ast)
            from_ast(ast)
          end
        end
      end
    end
  end
end
