# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      class FakeLetMethod
        MATCH_BODY = Regexp.union(
          /do(.*)end/m,
          /{(.*)}/m
        )

        # @param block_ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [RubyVM::AbstractSyntaxTree::Node]
        def self.transform_block(block_ast, code, method_name = nil)
          method_name ||= NodeTypes.let_method_name(block_ast)
          block_body = block_ast.children[1]
          matches = code.lines[block_body.first_lineno - 1..block_body.last_lineno - 1].join.match(MATCH_BODY)
          method_body = (matches[1] || matches[2]).strip

          ast = RubyVM::AbstractSyntaxTree.parse <<~RUBY
            def #{method_name}
              #{method_body}
            end
          RUBY

          ast.children[2]
        rescue SyntaxError
          raise "Failed to build fake let method: #{block_ast.inspect}, message: #{e.message}"
        ensure
          nil
        end
      end
    end
  end
end
