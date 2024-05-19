# frozen_string_literal: true

require_relative 'walker_base'

module Solargraph
  module Rspec
    module Correctors
      # Sets the correct namespace binding for example group blocks (it, example, etc.) and
      # hook blocks (before, after, around)
      class ExampleAndHookBlocksBindingCorrector < WalkerBase
        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def correct(source_map)
          # TODO: Remove unused block params
          rspec_walker.on_example_block do |_block_ast, location_range|
            bind_closest_namespace(location_range, source_map)

            yield [] if block_given?
          end

          rspec_walker.on_hook_block do |_block_ast, location_range|
            bind_closest_namespace(location_range, source_map)

            yield [] if block_given?
          end

          rspec_walker.on_let_method do |_let_method_ast, _method_name, location_range|
            bind_closest_namespace(location_range, source_map)

            yield [] if block_given?
          end

          rspec_walker.on_blocks_in_examples do |_block_ast, location_range|
            bind_closest_namespace(location_range, source_map)

            yield [] if block_given?
          end

          rspec_walker.on_subject do |_subject_ast, _method_name, location_range|
            bind_closest_namespace(location_range, source_map)

            yield [] if block_given?
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
          Util.build_public_method(
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
