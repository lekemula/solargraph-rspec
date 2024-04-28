# frozen_string_literal: true

require_relative 'walker_base'

module Solargraph
  module Rspec
    module Correctors
      # A corrector of RSpec parsed pins by Solargraph
      class ContextBlockNamespaceCorrector < WalkerBase
        # @param source_map [Solargraph::SourceMap]
        def correct(source_map)
          rspec_walker.on_each_context_block do |namespace_name, ast|
            original_block_pin = source_map.locate_block_pin(ast.location.begin.line, ast.location.begin.column)
            original_block_pin_index = source_map.pins.index(original_block_pin)
            location = Util.build_location(ast, source_map.filename)

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

            # RSpec executes "it" example blocks in the context of the example group.
            # @yieldsef changes the binding of the block to correct class.
            it_method_with_binding = Util.build_public_method(
              namespace_pin,
              'it',
              comments: ["@yieldself [#{namespace_pin.path}]"],
              scope: :class
            )

            namespace_pins << namespace_pin
            if block_given?
              yield [
                it_method_with_binding,
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
