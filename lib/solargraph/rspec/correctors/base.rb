# frozen_string_literal: true

module Solargraph
  module Rspec
    module Correctors
      # A corrector of RSpec parsed pins by Solargraph
      # @abstract
      class Base
        # @return [Array<Solargraph::Pin::Namespace>]
        attr_reader :namespace_pins

        # @return [Solargraph::Rspec::SpecWalker]
        attr_reader :rspec_walker

        # @return [Array<Solargraph::Pin::Base]
        attr_reader :added_pins

        # @param namespace_pins [Array<Solargraph::Pin::Base>]
        # @param rspec_walker [Solargraph::Rspec::SpecWalker]
        # @param added_pins [Array<Solargraph::Pin::Base>]
        def initialize(namespace_pins:, rspec_walker:, added_pins: [])
          @namespace_pins = namespace_pins
          @rspec_walker = rspec_walker
          @added_pins = added_pins
        end

        # @param _source_map [Solargraph::SourceMap]
        # @return [void]
        def correct(_source_map)
          raise NotImplementedError
        end

        private

        # @param pin [Solargraph::Pin::Base, nil]
        # @return [void]
        def add_pin(pin)
          return unless pin

          added_pins.push(pin)
        end

        # @param pins [Array<Solargraph::Pin::Base>]
        # @return [void]
        def add_pins(*pins)
          added_pins.concat(pins.flatten.compact)
        end

        # @return [Solargraph::Pin::Namespace]
        def root_example_group_namespace_pin
          Solargraph::Pin::Namespace.new(
            name: ROOT_NAMESPACE,
            location: PinFactory.dummy_location('lib/rspec/core/example_group.rb')
          )
        end

        # @param namespace_pins [Array<Pin::Namespace>]
        # @param line [Integer]
        # @return [Pin::Namespace, nil]
        def closest_namespace_pin(namespace_pins, line)
          namespace_pins.min_by do |namespace_pin|
            distance = line - namespace_pin.location.range.start.line
            distance >= 0 ? distance : Float::INFINITY
          end
        end
      end
    end
  end
end
