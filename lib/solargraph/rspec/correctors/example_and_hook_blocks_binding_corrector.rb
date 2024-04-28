# frozen_string_literal: true

require_relative 'walker_base'

module Solargraph
  module Rspec
    module Correctors
      # Sets the correct namespace binding for example group blocks (it, example, etc.) and
      # hook blocks (before, after, around)
      # TODO: Make it work for `example`, `xit`, `fit`, etc.
      class ExampleAndHookBlocksBindingCorrector < WalkerBase
        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def correct(source_map)
          rspec_walker.on_example_block do |block_ast|
            bind_closest_namespace(block_ast, source_map)

            yield [] if block_given?
          end

          rspec_walker.on_hook_block do |block_ast|
            bind_closest_namespace(block_ast, source_map)

            yield [] if block_given?
          end

          rspec_walker.after_walk do
            yield namespace_pins.flat_map { |namespace_pin| override_block_binding(namespace_pin) } if block_given?
          end
        end

        private

        # RSpec executes example and hook blocks (eg. it, before, after)in the context of the example group.
        # @yieldsef changes the binding of the block to correct class.
        # @return [Array<Solargraph::Pin::Method>]
        def override_block_binding(namespace_pin)
          %w[it before after around].map do |hook|
            Util.build_public_method(
              namespace_pin,
              hook,
              comments: ["@yieldself [#{namespace_pin.path}]"],
              scope: :class
            )
          end
        end

        # @param block_ast [Parser::AST::Node]
        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def bind_closest_namespace(block_ast, source_map)
          namespace_pin = closest_namespace_pin(namespace_pins, block_ast.loc.line)
          return unless namespace_pin

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
        end
      end
    end
  end
end
