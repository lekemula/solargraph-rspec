# frozen_string_literal: true

module Solargraph
  module Rspec
    class SpecWalker
      class FakeLetMethod
        MATCH_DO_END = /.*? do(.*)end/m.freeze
        MATCH_CURLY = /{(.*)}/m.freeze

        # @param block_ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [RubyVM::AbstractSyntaxTree::Node, nil]
        def self.transform_block(block_ast, code, method_name = nil)
          method_name ||= NodeTypes.let_method_name(block_ast)
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
        ensure
          nil
        end
      end
    end
  end
end
