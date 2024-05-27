# frozen_string_literal: true

require_relative 'base'
require 'yard'

module Solargraph
  module Rspec
    module Correctors
      # Includes DSL method helpers in the example group block for completion (ie. it, before, let, subject, etc.)
      class DslMethodsCorrector < Base
        # @return [Array<YARD::Registry>]
        def self.rspec_yardoc_registry
          @rspec_yardoc_registry ||= begin
            spec = Gem::Specification.find_by_name('rspec-core')
            require_paths = spec.require_paths.map { |path| File.join(spec.full_gem_path, path) }
            YARD::Registry.load(require_paths, true)
          end
        end

        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def correct(_source_map)
          rspec_walker.after_walk do
            namespace_pins.each do |namespace_pin|
              add_pins(context_dsl_methods(namespace_pin))
              add_pins(methods_with_example_binding(namespace_pin))
              debugger
              added_pins.last.docstring
            end
          end
        end

        private

        # RSpec executes example and hook blocks (eg. it, before, after)in the context of the example group.
        # @yieldsef changes the binding of the block to correct class.
        # @return [Array<Solargraph::Pin::Method>]
        def methods_with_example_binding(namespace_pin)
          rspec_context_block_methods.map do |method|
            PinFactory.build_public_method(
              namespace_pin,
              method.to_s,
              comments: [example_group_documentation(method), "@yieldself [#{namespace_pin.path}]"], # Fixes the binding of the block to the correct class
              scope: :class
            )
          end
        end

        # TODO: DSL methods should be defined once in the root example group and extended to all example groups.
        #   Fix this once Solargraph supports extending class methods.
        # @param namespace_pin [Solargraph::Pin::Base]
        # @return [Array<Solargraph::Pin::Base>]
        def context_dsl_methods(namespace_pin)
          Rspec::CONTEXT_METHODS.map do |method|
            PinFactory.build_public_method(
              namespace_pin,
              method.to_s,
              scope: :class
            )
          end
        end

        # @param method [String]
        # @return [String]
        def example_group_documentation(method)
          return unless Rspec::EXAMPLE_METHODS.include?(method)

          self.class.rspec_yardoc_registry.at("RSpec::Core::ExampleGroup.#{method}").docstring.all
        end

        # @return [Array<String>]
        def rspec_context_block_methods
          config.let_methods + Rspec::HOOK_METHODS + Rspec::EXAMPLE_METHODS
        end

        # @return [Solargraph::Rspec::Config]
        def config
          Solargraph::Rspec::Convention.config
        end
      end
    end
  end
end
