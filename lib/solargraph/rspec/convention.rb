# frozen_string_literal: true

require_relative 'config'
require_relative 'spec_walker'
require_relative 'annotations'
require_relative 'correctors/context_block_namespace_corrector'
require_relative 'correctors/example_and_hook_blocks_binding_corrector'
require_relative 'correctors/described_class_corrector'
require_relative 'correctors/let_methods_corrector'
require_relative 'correctors/subject_method_corrector'
require_relative 'correctors/context_block_methods_corrector'
require_relative 'correctors/dsl_methods_corrector'
require_relative 'pin_factory'

module Solargraph
  module Rspec
    ROOT_NAMESPACE = 'RSpec::ExampleGroups'
    HELPER_MODULES = [
      'RSpec::Matchers',
      'RSpec::Mocks::ExampleMethods', # https://github.com/rspec/rspec-mocks
      # TODO: Rspec-rails add a separate convetion and include conditionally based on spec type
      'RSpec::Rails::Matchers', # https://github.com/rspec/rspec-rails#helpful-rails-matchers
      # @see https://github.com/rspec/rspec-rails#what-tests-should-i-write
      'ActionController::TestCase::Behavior',
      'ActionMailer::TestCase::Behavior',
      'ActiveSupport::Testing::Assertions',
      'ActiveSupport::Testing::TimeHelpers',
      'ActiveSupport::Testing::FileFixtures',
      'ActiveRecord::TestFixtures',
      'ActionDispatch::Integration::Runner',
      'ActionDispatch::Routing::UrlFor',
      'ActionController::TemplateAssertions',
      # @see https://matchers.shoulda.io/docs/v6.2.0/#matchers
      'Shoulda::Matchers::ActiveModel',
      'Shoulda::Matchers::ActiveRecord',
      'Shoulda::Matchers::ActionController',
      'Shoulda::Matchers::Routing',
      'RSpec::Sidekiq::Matchers',
      'WebMock::API',
      'WebMock::Matchers',
      'Airborne'
    ].freeze
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
      Correctors::ContextBlockMethodsCorrector,
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

        Environ.new(pins: pins + annotation_pins)
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

        requires = %w[
          rspec
          shoulda-matchers
          shoulda/matchers
          rspec-rails
          actionmailer
          activesupport
          rspec-sidekiq
          webmock
          airborne
        ]
        Solargraph.logger.debug "[RSpec] added requires #{requires}"

        Environ.new(requires: requires, pins: pins)
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
        Solargraph.logger.debug "[RSpec] adding helper modules #{helper_modules}"
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

      # @return [Array<Pin::Base>]
      def annotation_pins
        ann = File.read(File.dirname(__FILE__) + '/annotations.rb')
        source = Solargraph::Source.load_string(ann, 'rspec-annotations.rb')
        map = Solargraph::SourceMap.map(source)
        map.pins
      end
    end
  end
end
