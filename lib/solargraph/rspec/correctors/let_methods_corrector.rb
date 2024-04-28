# frozen_string_literal: true

require_relative 'walker_base'

module Solargraph
  module Rspec
    module Correctors
      # Defines let-like methods in the example group block
      class LetMethodsCorrector < WalkerBase
        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def correct(_source_map)
          rspec_walker.on_let_method do |ast|
            namespace_pin = closest_namespace_pin(namespace_pins, ast.loc.line)
            next unless namespace_pin

            pin = rspec_let_method(namespace_pin, ast)
            yield [pin] if block_given?
          end
        end

        private

        # @param namespace [Pin::Namespace]
        # @param ast [Parser::AST::Node]
        # @param types [Array<String>, nil]
        # @return [Pin::Method, nil]
        def rspec_let_method(namespace, ast, types: nil)
          return unless ast.children
          return unless ast.children[2]&.children

          method_name = ast.children[2].children[0]&.to_s or return
          Util.build_public_method(
            namespace,
            method_name,
            types: types,
            location: Util.build_location(ast, namespace.filename),
            scope: :instance
          )
        end
      end
    end
  end
end
