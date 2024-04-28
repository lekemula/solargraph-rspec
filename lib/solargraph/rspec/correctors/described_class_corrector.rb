# frozen_string_literal: true

require_relative 'walker_base'

module Solargraph
  module Rspec
    module Correctors
      # Sets the correct namespace binding for example group blocks (it, example, etc.)
      # TODO: Make it work for `example`, `xit`, `fit`, etc.
      class DescribedClassCorrector < WalkerBase
        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def correct(_source_map)
          rspec_walker.on_described_class do |ast, described_class_name|
            namespace_pin = closest_namespace_pin(namespace_pins, ast.loc.line)
            next unless namespace_pin

            described_class_pin = rspec_described_class_method(namespace_pin, ast, described_class_name)
            yield [described_class_pin].compact if block_given?
          end
        end

        private

        # @param namespace [Pin::Namespace]
        # @param ast [Parser::AST::Node]
        # @param described_class_name [String]
        # @return [Pin::Method, nil]
        def rspec_described_class_method(namespace, ast, described_class_name)
          Util.build_public_method(
            namespace,
            'described_class',
            types: ["Class<#{described_class_name}>"],
            location: Util.build_location(ast, namespace.filename),
            scope: :instance
          )
        end
      end
    end
  end
end
