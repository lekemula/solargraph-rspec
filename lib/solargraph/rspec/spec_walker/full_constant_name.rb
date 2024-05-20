# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      class FullConstantName
        class << self
          # @param ast [RubyVM::AbstractSyntaxTree::Node]
          # @return [String]
          def from_ast(ast)
            raise 'Node is not a constant' unless NodeTypes.a_constant?(ast)

            if ast.type == :CONST
              ast.children[0].to_s
            elsif ast.type == :COLON2
              name = ast.children[1].to_s
              "#{from_ast(ast.children[0])}::#{name}"
            end
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
