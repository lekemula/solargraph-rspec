# frozen_string_literal: true

require_relative 'let_methods_corrector'

module Solargraph
  module Rspec
    module Correctors
      # Defines let-like methods in the example group block
      class SubjectMethodCorrector < LetMethodsCorrector
        # @return [Array<Pin::Base>]
        attr_reader :added_pins

        # @param namespace_pins [Array<Pin::Namespace>]
        # @param added_pins [Array<Pin::Base>]
        # @param rspec_walker [Solargraph::Rspec::SpecWalker]
        def initialize(namespace_pins:, rspec_walker:, added_pins:)
          super(namespace_pins: namespace_pins, rspec_walker: rspec_walker)

          @added_pins = added_pins
        end

        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def correct(_source_map)
          rspec_walker.on_subject do |subject_name, location_range, fake_method_ast|
            namespace_pin = closest_namespace_pin(namespace_pins, location_range.start.line)
            next unless namespace_pin

            subject_pin = rspec_subject_method(namespace_pin, subject_name, location_range, fake_method_ast)
            yield [subject_pin].compact if block_given?
          end

          rspec_walker.after_walk do
            next unless described_class_pin

            namespace_pin = closest_namespace_pin(namespace_pins, described_class_pin.location.range.start.line)

            yield [implicit_subject_pin(described_class_pin, namespace_pin)] if block_given? && namespace_pin
          end
        end

        private

        # @return [Pin::Method, nil]
        def described_class_pin
          @described_class_pin ||= added_pins.find { |pin| pin.is_a?(Pin::Method) && pin.name == 'described_class' }
        end

        # @param namespace_pin [Pin::Namespace]
        # @param subject_name [String, nil]
        # @param location_range [Solargraph::Range]
        # @param fake_method_ast [Parser::AST::Node]
        # @return [Pin::Method]
        def rspec_subject_method(namespace_pin, subject_name, location_range, fake_method_ast)
          method_name = subject_name || 'subject'
          rspec_let_method(namespace_pin, method_name, location_range, fake_method_ast)
        end

        # @param described_class_pin [Pin::Method]
        # @param namespace_pin [Pin::Namespace]
        # @return [Pin::Method]
        def implicit_subject_pin(described_class_pin, namespace_pin)
          described_class = described_class_pin.return_type.first.subtypes.first.name

          PinFactory.build_public_method(
            namespace_pin,
            'subject',
            types: ["::#{described_class}"],
            location: described_class_pin.location,
            scope: :instance
          )
        end
      end
    end
  end
end
