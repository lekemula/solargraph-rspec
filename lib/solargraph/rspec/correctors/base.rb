# frozen_string_literal: true

module Solargraph
  module Rspec
    module Correctors
      # A corrector of RSpec parsed pins by Solargraph
      # @abstract
      class Base
        # @return [Array<Solargraph::Pin::Namespace>]
        attr_reader :namespace_pins

        # @param namespace_pins [Array<Solargraph::Pin::Base>]
        def initialize(namespace_pins:)
          @namespace_pins = namespace_pins
        end

        # @param _source_map [Solargraph::SourceMap]
        # @yield [Array<Solargraph::Pin::Base>] Pins to be added to the source map
        # @return [void]
        def correct(_source_map)
          raise NotImplementedError
        end

        private

        # @return [Solargraph::Pin::Namespace]
        def root_example_group_namespace_pin
          Solargraph::Pin::Namespace.new(
            name: ROOT_NAMESPACE,
            location: Util.dummy_location('lib/rspec/core/example_group.rb')
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
