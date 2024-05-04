# frozen_string_literal: true

require_relative 'walker_base'

module Solargraph
  module Rspec
    module Correctors
      # Sets the correct namespace binding for example group blocks (it, example, etc.) and
      # hook blocks (before, after, around)
      class ExampleAndHookBlocksBindingCorrector < WalkerBase
        # @param namespace_pins [Array<Solargraph::Pin::Base>]
        # @param rspec_walker [Solargraph::Rspec::SpecWalker]
        # @param config [Solargraph::Rspec::Config]
        def initialize(namespace_pins:, rspec_walker:, config:)
          super(namespace_pins: namespace_pins, rspec_walker: rspec_walker)
          @config = config
        end

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

          rspec_walker.on_let_method do |let_method_ast|
            bind_closest_namespace(let_method_ast, source_map)

            yield [] if block_given?
          end

          rspec_walker.after_walk do
            yield namespace_pins.flat_map { |namespace_pin| override_block_binding(namespace_pin) } if block_given?
          end
        end

        private

        # @return [Solargraph::Rspec::Config]
        attr_reader :config

        # RSpec executes example and hook blocks (eg. it, before, after)in the context of the example group.
        # @yieldsef changes the binding of the block to correct class.
        # @return [Array<Solargraph::Pin::Method>]
        def override_block_binding(namespace_pin)
          rspec_context_block_methods.map do |method|
            Util.build_public_method(
              namespace_pin,
              method.to_s,
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

        # @return [Array<String>]
        def rspec_context_block_methods
          config.let_methods + Rspec::HOOK_METHODS + Rspec::EXAMPLE_METHODS
        end
      end
    end
  end
end
