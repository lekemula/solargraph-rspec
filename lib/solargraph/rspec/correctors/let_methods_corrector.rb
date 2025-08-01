# frozen_string_literal: true

require_relative 'base'

module Solargraph
  module Rspec
    module Correctors
      # Defines let-like methods in the example group block
      class LetMethodsCorrector < Base
        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def correct(_source_map)
          rspec_walker.on_let_method do |let_name, location_range, fake_method_ast|
            namespace_pin = closest_namespace_pin(namespace_pins, location_range.start.line)
            next unless namespace_pin

            pin = rspec_let_method(namespace_pin, let_name, location_range, fake_method_ast)
            add_pin(pin)
          end
        end

        private

        # @param namespace [Pin::Namespace]
        # @param method_name [String]
        # @param node [::Parser::AST::Node, nil]
        # @param types [Array<String>, nil]
        # @return [Pin::Method, nil]
        def rspec_let_method(namespace, method_name, location_range, node = nil, types: nil)
          PinFactory.build_public_method(
            namespace,
            method_name,
            node: node,
            types: types,
            location: PinFactory.build_location(location_range, namespace.filename),
            scope: :instance
          )
        end
      end
    end
  end
end
