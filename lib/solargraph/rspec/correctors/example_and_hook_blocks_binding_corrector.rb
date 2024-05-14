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

          rspec_walker.on_blocks_in_examples do |block_ast|
            bind_closest_namespace(block_ast, source_map)

            yield [] if block_given?
          end

          rspec_walker.on_subject do |_subject_ast, block_ast|
            bind_closest_namespace(block_ast, source_map)

            yield [] if block_given?
          end
        end

        private

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
