# frozen_string_literal: true

require_relative 'base'

module Solargraph
  module Rspec
    module Correctors
      # RSpec executes example and hook blocks in the context of the example group (ie. describe blocks).
      # This correctors sets the right bindings to those blocks.
      class ExampleAndHookBlocksBindingCorrector < Base
        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def correct(source_map)
          # @type [Hash{Solargraph::Pin::Block => Solargraph::Pin::Block}]
          @corrected_blocks = {}

          rspec_walker.on_example_block do |location_range|
            bind_closest_namespace(location_range, source_map)
          end

          rspec_walker.on_hook_block do |location_range|
            bind_closest_namespace(location_range, source_map)
          end

          rspec_walker.on_let_method do |_method_name, location_range|
            bind_closest_namespace(location_range, source_map)
          end

          rspec_walker.on_blocks_in_examples do |location_range|
            bind_closest_namespace(location_range, source_map)
          end

          rspec_walker.on_subject do |_method_name, location_range|
            bind_closest_namespace(location_range, source_map)
          end

          rspec_walker.after_walk do
            source_map.locals.each do |p|
              next unless p.is_a? Solargraph::Pin::BaseVariable

              fixed_block = @corrected_blocks[p.closure]

              # This might not be be best best practice, but imo its much simpler to keep up with updates and such
              p.instance_variable_set('@closure', fixed_block) unless fixed_block.nil?
            end
          end
        end

        private

        # @param location_range [Solargraph::Range]
        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def bind_closest_namespace(location_range, source_map)
          namespace_pin = closest_namespace_pin(namespace_pins, location_range.start.line)
          return unless namespace_pin

          original_block_pin = source_map.locate_block_pin(location_range.start.line,
                                                           location_range.start.column)
          original_block_pin_index = source_map.pins.index(original_block_pin)
          fixed_namespace_block_pin = Solargraph::Pin::Block.new(
            closure: example_run_method(namespace_pin),
            location: original_block_pin.location,
            receiver: original_block_pin.receiver,
            scope: original_block_pin.scope
          )

          source_map.pins[original_block_pin_index] = fixed_namespace_block_pin
        end

        # @param namespace_pin [Solargraph::Pin::Namespace]
        # @return [Solargraph::Pin::Method]
        def example_run_method(namespace_pin)
          PinFactory.build_public_method(
            namespace_pin,
            'run',
            # https://github.com/rspec/rspec-core/blob/main/lib/rspec/core/example.rb#L246
            location: Solargraph::Location.new('lib/rspec/core/example.rb', Solargraph::Range.from_to(246, 1, 297, 1))
          )
        end
      end
    end
  end
end
