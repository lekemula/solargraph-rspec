# frozen_string_literal: true

require_relative 'let_methods_corrector'

module Solargraph
  module Rspec
    module Correctors
      # Defines let-like methods in the example group block
      class ImplicitSubjectMethodCorrector < Base
        # @return [Pin::Method]
        attr_reader :described_class_pin

        # @param namespace_pins [Array<Pin::Namespace>]
        # @param described_class_pin [Pin::Method]
        def initialize(namespace_pins:, described_class_pin:)
          super(namespace_pins: namespace_pins)

          @described_class_pin = described_class_pin
        end

        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def correct(_source_map)
          namespace_pin = closest_namespace_pin(namespace_pins, described_class_pin.location.range.start.line)

          yield [implicit_subject_pin(described_class_pin, namespace_pin)] if block_given? && namespace_pin
        end

        private

        # @param described_class_pin [Pin::Method]
        # @param namespace_pin [Pin::Namespace]
        # @return [Pin::Method]
        def implicit_subject_pin(described_class_pin, namespace_pin)
          described_class = described_class_pin.return_type.first.subtypes.first.name

          PinFactory.build_public_method(
            namespace_pin,
            'subject',
            types: [described_class],
            location: described_class_pin.location,
            scope: :instance
          )
        end
      end
    end
  end
end
