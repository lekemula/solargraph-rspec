# frozen_string_literal: true

require_relative 'config'
require_relative 'spec_walker'
require_relative 'annotations'
require_relative 'correctors/context_block_namespace_corrector'
require_relative 'correctors/example_and_hook_blocks_binding_corrector'
require_relative 'correctors/described_class_corrector'
require_relative 'correctors/let_methods_corrector'
require_relative 'correctors/subject_method_corrector'
require_relative 'correctors/dsl_methods_corrector'
require_relative 'factory_bot'
require_relative 'gems'
require_relative 'pin_factory'
require_relative 'rspec_configure'

module Solargraph
  module Rspec
    ROOT_NAMESPACE = 'RSpec::ExampleGroups'
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

    # @type [Array<Class<Correctors::Base>>]
    CORRECTOR_CLASSES = [
      Correctors::ContextBlockNamespaceCorrector,
      Correctors::DescribedClassCorrector,
      Correctors::DslMethodsCorrector,
      Correctors::ExampleAndHookBlocksBindingCorrector,
      Correctors::LetMethodsCorrector,
      Correctors::SubjectMethodCorrector
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

      # @param _yard_map [YardMap]
      # @return [Environ]
      def global(_yard_map)
        pins = []
        pins += Solargraph::Rspec::Gems.include_helper_pins(
          root_example_group_namespace_pin: root_example_group_namespace_pin
        )
        pins += annotation_pins

        # Add pins from RSpec.configure blocks
        rspec_configure = RSpecConfigure.new(
          config: config,
          root_namespace_pin: root_example_group_namespace_pin
        )
        pins += rspec_configure.pins
        pins += factory_bot_pins

        # TODO: Include gem requires conditionally based on Gemfile definition
        requires = Solargraph::Rspec::Gems.gem_names + rspec_configure.extra_requires

        if pins.any?
          Solargraph.logger.debug(
            "[RSpec] added global pins #{pins.map(&:inspect)}"
          )
        end

        Solargraph.logger.debug "[RSpec] added requires #{requires}"

        Environ.new(requires: requires, pins: pins)
      rescue StandardError, SyntaxError => e
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

        rspec_walker = SpecWalker.new(source_map: source_map, config: config)

        CORRECTOR_CLASSES.each do |corrector_class|
          corrector_class.new(
            namespace_pins: namespace_pins,
            rspec_walker: rspec_walker,
            added_pins: pins
          ).correct(source_map)
        end

        rspec_walker.walk!
        pins += namespace_pins

        if pins.any?
          Solargraph.logger.debug(
            "[RSpec] added #{pins.map(&:inspect)} to #{source_map.filename}"
          )
        end

        Environ.new(requires: [], pins: pins)
      rescue StandardError, SyntaxError => e
        raise e if ENV['SOLARGRAPH_DEBUG']

        Solargraph.logger.warn(
          "[RSpec] Error processing #{source_map.filename}: #{e.message}\n#{e.backtrace.join("\n")}"
        )
        EMPTY_ENVIRON
      end

      # The factory methods are provided per object rather than globally: methods a convention provides for a
      # namespace come before the store's, so they win over the factory_bot gem's own `create`/`build` pins.
      #
      # @param _api_map [ApiMap]
      # @param rooted_tag [String]
      # @param scope [Symbol]
      # @param _visibility [Array<Symbol>]
      # @param _deep [Boolean]
      # @param _skip [Set<String>]
      # @param _no_core [Boolean]
      # @return [Environ]
      def object(_api_map, rooted_tag, scope, _visibility, _deep, _skip, _no_core)
        return EMPTY_ENVIRON unless @factory_bot && scope == :instance

        pins = @factory_bot.method_pins(rooted_tag.delete_prefix('::'))
        pins.empty? ? EMPTY_ENVIRON : Environ.new(pins: pins)
      rescue StandardError => e
        raise e if ENV['SOLARGRAPH_DEBUG']

        Solargraph.logger.warn("[RSpec] Error processing factory pins for #{rooted_tag}: #{e.message}")
        EMPTY_ENVIRON
      end

      private

      # @return [Config]
      def config
        self.class.config
      end

      # @return [Array<Pin::Base>]
      def factory_bot_pins
        @factory_bot = FactoryBot.new
        @factory_bot.namespace_pins + @factory_bot.factory_parameter_pins
      rescue StandardError => e
        raise e if ENV['SOLARGRAPH_DEBUG']

        Solargraph.logger.warn("[RSpec] Error processing factory pins: #{e.message}")
        []
      end

      # @return [Pin::Namespace]
      def root_example_group_namespace_pin
        Solargraph::Pin::Namespace.new(
          name: ROOT_NAMESPACE,
          location: PinFactory.dummy_location('lib/rspec/core/example_group.rb')
        )
      end

      # @return [Array<Pin::Base>]
      def annotation_pins
        ann = File.read("#{File.dirname(__FILE__)}/annotations.rb")
        source = Solargraph::Source.load_string(ann, 'rspec-annotations.rb')
        map = Solargraph::SourceMap.map(source)
        map.pins
      end
    end
  end
end
