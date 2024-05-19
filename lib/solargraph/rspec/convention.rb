# frozen_string_literal: true

require_relative 'config'
require_relative 'ruby_vm_spec_walker'
require_relative 'correctors/context_block_namespace_corrector'
require_relative 'correctors/example_and_hook_blocks_binding_corrector'
require_relative 'correctors/described_class_corrector'
require_relative 'correctors/let_methods_corrector'
require_relative 'correctors/subject_method_corrector'
require_relative 'correctors/context_block_methods_corrector'
require_relative 'correctors/implicit_subject_method_corrector'
require_relative 'correctors/dsl_methods_corrector'
require_relative 'pin_factory'

module Solargraph
  module Rspec
    ROOT_NAMESPACE = 'RSpec::ExampleGroups'
    HELPER_MODULES = ['RSpec::Matchers'].freeze
    HOOK_METHODS = %w[before after around].freeze
    LET_METHODS = %w[let let!].freeze
    SUBJECT_METHODS = %w[subject subject!].freeze
    EXAMPLE_METHODS = %w[
      example
      it
      specify
      focus
      fexample
      fit
      fspecify
      xexample
      xit
      xspecify
      skip
      pending
    ].freeze

    CONTEXT_METHODS = %w[
      example_group
      describe
      context
      xdescribe
      xcontext
      fdescribe
      fcontext
      shared_examples
      include_examples
      it_behaves_like
      it_should_behave_like
      shared_context
      include_context
    ].freeze

    # Provides completion for RSpec DSL and helper methods.
    #   - `describe` and `context` blocks
    #   - `let` and `let!` methods
    #   - `subject` method
    #   - `described_class` method
    #   - `it` method with correct binding
    #   - `RSpec::Matchers` module
    class Convention < Solargraph::Convention::Base
      # @return [Config]
      def self.config
        @config ||= Config.new
      end

      # @param filename [String]
      # @return [Boolean]
      def self.valid_filename?(filename)
        filename.include?('spec/')
      end

      # @param yard_map [YardMap]
      # @return [Environ]
      def global(_yard_map)
        pins = []
        pins += include_helper_pins

        if pins.any?
          Solargraph.logger.debug(
            "[RSpec] added global pins #{pins.map(&:inspect)}"
          )
        end

        Environ.new(pins: pins)
      rescue StandardError => e
        raise e if ENV['SOLARGRAPH_DEBUG']

        Solargraph.logger.warn(
          "[RSpec] Error processing global pins: #{e.message}\n#{e.backtrace.join("\n")}"
        )
        EMPTY_ENVIRON
      end

      # @param source_map [SourceMap]
      # @return [Environ]
      def local(source_map)
        Solargraph.logger.debug "[RSpec] processing #{source_map.filename}"

        return EMPTY_ENVIRON unless self.class.valid_filename?(source_map.filename)

        # @type [Array<Pin::Base>]
        pins = []
        # @type [Array<Pin::Namespace>]
        namespace_pins = []

        rspec_walker = RubyVMSpecWalker.new(source_map: source_map, config: config)

        Correctors::ContextBlockNamespaceCorrector.new(
          namespace_pins: namespace_pins,
          rspec_walker: rspec_walker
        ).correct(source_map) do |pins_to_add|
          pins += pins_to_add
        end

        Correctors::ExampleAndHookBlocksBindingCorrector.new(
          namespace_pins: namespace_pins,
          rspec_walker: rspec_walker
        ).correct(source_map) do |pins_to_add|
          pins += pins_to_add
        end

        # @type [Pin::Method, nil]
        described_class_pin = nil
        Correctors::DescribedClassCorrector.new(
          namespace_pins: namespace_pins,
          rspec_walker: rspec_walker
        ).correct(
          source_map
        ) do |pins_to_add|
          described_class_pin = pins_to_add.first
          pins += pins_to_add
        end

        Correctors::LetMethodsCorrector.new(
          namespace_pins: namespace_pins,
          rspec_walker: rspec_walker
        ).correct(
          source_map
        ) do |pins_to_add|
          pins += pins_to_add
        end

        # @type [Pin::Method, nil]
        subject_pin = nil
        Correctors::SubjectMethodCorrector.new(
          namespace_pins: namespace_pins,
          rspec_walker: rspec_walker
        ).correct(
          source_map
        ) do |pins_to_add|
          subject_pin = pins_to_add.first
          pins += pins_to_add
        end

        Correctors::ContextBlockMethodsCorrector.new(
          namespace_pins: namespace_pins,
          rspec_walker: rspec_walker
        ).correct(source_map) do |pins_to_add|
          pins += pins_to_add
        end

        Correctors::DslMethodsCorrector.new(
          namespace_pins: namespace_pins,
          rspec_walker: rspec_walker,
          config: config
        ).correct(
          source_map
        ) do |pins_to_add|
          pins += pins_to_add
        end

        rspec_walker.walk!
        pins += namespace_pins

        # Implicit subject
        if !subject_pin && described_class_pin
          Correctors::ImplicitSubjectMethodCorrector.new(
            namespace_pins: namespace_pins,
            described_class_pin: described_class_pin
          ).correct(
            source_map
          ) do |pins_to_add|
            subject_pin = pins_to_add.first
            pins += pins_to_add
          end
        end

        if pins.any?
          Solargraph.logger.debug(
            "[RSpec] added #{pins.map(&:inspect)} to #{source_map.filename}"
          )
        end

        Environ.new(requires: ['rspec'], pins: pins)
      rescue StandardError => e
        raise e if ENV['SOLARGRAPH_DEBUG']

        Solargraph.logger.warn(
          "[RSpec] Error processing #{source_map.filename}: #{e.message}\n#{e.backtrace.join("\n")}"
        )
        EMPTY_ENVIRON
      end

      private

      # @param helper_modules [Array<String>]
      # @param source_map [SourceMap]
      # @return [Array<Pin::Base>]
      def include_helper_pins(helper_modules: HELPER_MODULES)
        helper_modules.map do |helper_module|
          PinFactory.build_module_include(
            root_example_group_namespace_pin,
            helper_module,
            root_example_group_namespace_pin.location
          )
        end
      end

      # @return [Config]
      def config
        self.class.config
      end

      # @return [Pin::Namespace]
      def root_example_group_namespace_pin
        Solargraph::Pin::Namespace.new(
          name: ROOT_NAMESPACE,
          location: PinFactory.dummy_location('lib/rspec/core/example_group.rb')
        )
      end
    end
  end
end
