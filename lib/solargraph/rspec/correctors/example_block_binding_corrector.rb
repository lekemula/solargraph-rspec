# frozen_string_literal: true

require_relative 'walker_base'

module Solargraph
  module Rspec
    module Correctors
      # Sets the correct namespace binding for example group blocks (it, example, etc.)
      # TODO: Make it work for `example`, `xit`, `fit`, etc.
      class ExampleBlockBindingCorrector < WalkerBase
        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def correct(source_map)
          rspec_walker.on_example_block do |block_ast|
            namespace_pin = closest_namespace_pin(namespace_pins, block_ast.loc.line)
            next unless namespace_pin

            original_block_pin = source_map.locate_block_pin(block_ast.location.begin.line,
                                                             block_ast.location.begin.column)
            original_block_pin_index = source_map.pins.index(original_block_pin)
            fixed_namespace_block_pin = Solargraph::Pin::Block.new(
              closure: namespace_pin,
              location: original_block_pin.location,
              receiver: original_block_pin.receiver,
              scope: original_block_pin.scope
            )

            source_map.pins[original_block_pin_index] = fixed_namespace_block_pin

            yield [] if block_given?
          end
        end
      end
    end
  end
end
