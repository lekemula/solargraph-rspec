# frozen_string_literal: true

require_relative 'base'

module Solargraph
  module Rspec
    module Correctors
      # A corrector that corrects pure ruby method blocks namespace defined inside describe/context blocks.
      class ContextBlockMethodsCorrector < Base
        # @param source_map [Solargraph::SourceMap]
        def correct(source_map)
          source_map.pins.each_with_index do |pin, index|
            next unless pin.is_a?(Solargraph::Pin::Method)

            namespace_pin = closest_namespace_pin(namespace_pins, pin.location.range.start.line)
            next unless namespace_pin

            source_map.pins[index] = Solargraph::Pin::Method.new(
              visibility: pin.visibility,
              parameters: pin.parameters,
              closure: namespace_pin,
              node: pin.node,
              signatures: pin.signatures,
              location: pin.location,
              name: pin.name,
              scope: pin.scope,
              comments: pin.comments
            )
          end
        end
      end
    end
  end
end
