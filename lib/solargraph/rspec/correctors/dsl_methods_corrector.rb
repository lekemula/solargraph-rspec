# frozen_string_literal: true

require_relative 'walker_base'

module Solargraph
  module Rspec
    module Correctors
      class DslMethodsCorrector < WalkerBase
        # @param namespace_pins [Array<Solargraph::Pin::Base>]
        # @param rspec_walker [Solargraph::Rspec::SpecWalker]
        # @param config [Solargraph::Rspec::Config]
        def initialize(namespace_pins:, rspec_walker:, config:)
          super(namespace_pins: namespace_pins, rspec_walker: rspec_walker)
          @config = config
        end

        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def correct(_source_map)
          rspec_walker.after_walk do
            if block_given?
              yield namespace_pins.flat_map { |namespace_pin| add_context_dsl_methods(namespace_pin) }
              yield namespace_pins.flat_map { |namespace_pin| add_methods_with_example_binding(namespace_pin) }
            end
          end
        end

        private

        # @return [Solargraph::Rspec::Config]
        attr_reader :config

        # RSpec executes example and hook blocks (eg. it, before, after)in the context of the example group.
        # @yieldsef changes the binding of the block to correct class.
        # @return [Array<Solargraph::Pin::Method>]
        def add_methods_with_example_binding(namespace_pin)
          rspec_context_block_methods.map do |method|
            Util.build_public_method(
              namespace_pin,
              method.to_s,
              comments: ["@yieldself [#{namespace_pin.path}]"], # Fixes the binding of the block to the correct class
              scope: :class
            )
          end
        end

        # TODO: DSL methods should be defined once in the root example group and extended to all example groups.
        #   Fix this once Solargraph supports extending class methods.
        # @param namespace_pin [Solargraph::Pin::Base]
        # @return [Array<Solargraph::Pin::Base>]
        def add_context_dsl_methods(namespace_pin)
          Rspec::CONTEXT_METHODS.map do |method|
            Util.build_public_method(
              namespace_pin,
              method.to_s,
              scope: :class
            )
          end
        end

        # @return [Array<String>]
        def rspec_context_block_methods
          config.let_methods + Rspec::HOOK_METHODS + Rspec::EXAMPLE_METHODS
        end
      end
    end
  end
end
