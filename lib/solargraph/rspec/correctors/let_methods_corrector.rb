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
          # TODO: Remove _block_ast
          rspec_walker.on_let_method do |_block_ast, let_name, location_range|
            namespace_pin = closest_namespace_pin(namespace_pins, location_range.start.line)
            next unless namespace_pin

            pin = rspec_let_method(namespace_pin, let_name, location_range)
            yield [pin] if block_given?
          end
        end

        private

        # @param namespace [Pin::Namespace]
        # @param method_name [String]
        # @param types [Array<String>, nil]
        # @return [Pin::Method, nil]
        def rspec_let_method(namespace, method_name, location_range, types: nil)
          Util.build_public_method(
            namespace,
            method_name,
            types: types,
            location: PinFactory.build_location(location_range, namespace.filename),
            scope: :instance
          )
        end
      end
    end
  end
end
