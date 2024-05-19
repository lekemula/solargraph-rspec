# frozen_string_literal: true

require_relative 'walker_base'

module Solargraph
  module Rspec
    module Correctors
      # A corrector of RSpec parsed pins by Solargraph
      class ContextBlockNamespaceCorrector < WalkerBase
        # @param source_map [Solargraph::SourceMap]
        def correct(source_map)
          # @param location_range [Solargraph::Range]
          rspec_walker.on_each_context_block do |namespace_name, location_range|
            original_block_pin = source_map.locate_block_pin(location_range.start.line, location_range.start.column)
            original_block_pin_index = source_map.pins.index(original_block_pin)
            location = PinFactory.build_location(location_range, source_map.filename)

            # Define a dynamic module for the example group block
            # Example:
            #   RSpec.describe Foo::Bar do  # => module RSpec::ExampleGroups::FooBar
            #     context 'some context' do # => module RSpec::ExampleGroups::FooBar::SomeContext
            #     end
            #   end
            namespace_pin = Solargraph::Pin::Namespace.new(
              name: namespace_name,
              location: location
            )

            fixed_namespace_block_pin = Solargraph::Pin::Block.new(
              closure: namespace_pin,
              location: original_block_pin.location,
              receiver: original_block_pin.receiver,
              scope: original_block_pin.scope
            )

            source_map.pins[original_block_pin_index] = fixed_namespace_block_pin

            # Include DSL methods in the example group block
            # TOOD: This does not work on solagraph! Class methods are not included from parent class.
            namespace_extend_pin = Util.build_module_extend(
              namespace_pin,
              root_example_group_namespace_pin.name,
              location
            )

            # Include parent example groups to share let definitions
            parent_namespace_name = namespace_name.split('::')[0..-2].join('::')
            namespace_include_pin = Util.build_module_include(
              namespace_pin,
              parent_namespace_name,
              location
            )

            namespace_pins << namespace_pin
            if block_given?
              yield [
                namespace_include_pin,
                namespace_extend_pin
              ]
            end
          end
        end
      end
    end
  end
end
