# frozen_string_literal: true

require_relative 'base'

module Solargraph
  module Rspec
    module Correctors
      # RSpec generates a namespace class for each context block. This corrector add the pins for those namespaces.
      class ContextBlockNamespaceCorrector < Base
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

            override_closure(original_block_pin, namespace_pin)

            # Include DSL methods in the example group block
            # TODO: This does not work on solagraph! Class methods are not included from parent class.
            namespace_extend_pin = PinFactory.build_module_extend(
              namespace_pin,
              root_example_group_namespace_pin.name,
              location
            )

            # Include parent example groups to share let definitions
            parent_namespace_name = namespace_name.split('::')[0..-2].join('::')
            namespace_include_pin = PinFactory.build_module_include(
              namespace_pin,
              parent_namespace_name,
              location
            )

            namespace_pins << namespace_pin

            add_pins(namespace_extend_pin, namespace_include_pin)
          end
        end
      end
    end
  end
end
