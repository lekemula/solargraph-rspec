# frozen_string_literal: true

require_relative 'walker_base'

module Solargraph
  module Rspec
    module Correctors
      class DescribedClassCorrector < WalkerBase
        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def correct(_source_map)
          rspec_walker.on_described_class do |described_class_name, location_range|
            namespace_pin = closest_namespace_pin(namespace_pins, location_range.start.line)
            next unless namespace_pin

            described_class_pin = rspec_described_class_method(namespace_pin, location_range, described_class_name)
            yield [described_class_pin].compact if block_given?
          end
        end

        private

        # @param namespace [Pin::Namespace]
        # @param location_range [Solargraph::Range]
        # @param described_class_name [String]
        # @return [Pin::Method, nil]
        def rspec_described_class_method(namespace, location_range, described_class_name)
          PinFactory.build_public_method(
            namespace,
            'described_class',
            types: ["Class<::#{described_class_name}>"],
            location: PinFactory.build_location(location_range, namespace.filename),
            scope: :instance
          )
        end
      end
    end
  end
end
