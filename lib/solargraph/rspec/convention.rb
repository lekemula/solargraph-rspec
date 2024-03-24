# frozen_string_literal: true

require_relative 'config'
require_relative 'spec_walker'
require_relative 'util'

module Solargraph
  module Rspec
    ROOT_NAMESPACE = 'RSpec::ExampleGroups'

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
        EMPTY_ENVIRON
      end

      # @param source_map [SourceMap]
      # @return [Array<Pin::Base>]
      def local(source_map)
        Solargraph.logger.debug "[RSpec] processing #{source_map.filename}"

        return EMPTY_ENVIRON unless self.class.valid_filename?(source_map.filename)
        # @type [Array<Pin::Base>]
        pins = []
        # @type [Array<Pin::Namespace>]
        namespace_pins = []
        # @type [Array<Pin::Block>]
        block_pins = []

        pins += include_helper_pins(source_map: source_map)

        rspec_walker = SpecWalker.new(source_map: source_map, config: config)

        rspec_walker.on_each_context_block do |namespace_name, ast|
          location = Util.build_location(ast, source_map.filename)

          namespace_pin = Solargraph::Pin::Namespace.new(
            name: namespace_name,
            location: location
          )

          # Define a dynamic module for the example group block
          # Example:
          #   RSpec.describe Foo::Bar do  # => module RSpec::ExampleGroups::FooBar
          #     context 'some context' do # => module RSpec::ExampleGroups::FooBar::SomeContext
          #     end
          #   end
          block_pin = Solargraph::Pin::Block.new(
            closure: namespace_pin,
            location: location,
            receiver: RubyVM::AbstractSyntaxTree.parse('it()').children[2]
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
          block_pins << block_pin
          pins << it_method_with_binding
          pins << namespace_include_pin
        end

        # @type [Pin::Method, nil]
        described_class_pin = nil
        rspec_walker.on_described_class do |ast, described_class_name|
          namespace_pin = closest_namespace_pin(namespace_pins, ast.loc.line)
          next unless namespace_pin

          described_class_pin = rspec_described_class_method(namespace_pin, ast, described_class_name)
          pins << described_class_pin unless described_class_pin.nil?
        end

        rspec_walker.on_let_method do |ast|
          namespace_pin = closest_namespace_pin(namespace_pins, ast.loc.line)
          next unless namespace_pin

          pin = rspec_let_method(namespace_pin, ast)
          pins << pin unless pin.nil?
        end

        # @type [Pin::Method, nil]
        subject_pin = nil
        rspec_walker.on_subject do |ast|
          namespace_pin = closest_namespace_pin(namespace_pins, ast.loc.line)
          next unless namespace_pin

          subject_pin = rspec_let_method(namespace_pin, ast)
          pins << subject_pin unless subject_pin.nil?
        end

        rspec_walker.walk!
        pins += namespace_pins
        pins += block_pins

        # Implicit subject
        if !subject_pin && described_class_pin
          namespace_pin = closest_namespace_pin(namespace_pins, described_class_pin.location.range.start.line)
          pins << implicit_subject_pin(described_class_pin, namespace_pin)
        end

        if pins.any?
          Solargraph.logger.debug(
            "[RSpec] added #{pins.map(&:inspect)} to #{source_map.filename}"
          )
        end

        Environ.new(pins: pins)
      rescue StandardError => e
        Solargraph.logger.warn(
          "[RSpec] Error processing #{source_map.filename}: #{e.message}\n#{e.backtrace.join("\n")}"
        )
        EMPTY_ENVIRON
      end

      private

      # @param described_class_pin [Pin::Method]
      # @param namespace_pin [Pin::Namespace]
      # @return [Pin::Method]
      def implicit_subject_pin(described_class_pin, namespace_pin)
        described_class = described_class_pin.return_type.first.subtypes.first.name

        Util.build_public_method(
          namespace_pin,
          'subject',
          types: [described_class],
          location: described_class_pin.location,
          scope: :instance
        )
      end

      # @param helper_modules [Array<String>]
      # @param source_map [SourceMap]
      # @return [Array<Pin::Base>]
      def include_helper_pins(source_map:, helper_modules: ['RSpec::Matchers'])
        pins = []

        example_group_pin = Solargraph::Pin::Namespace.new(
          name: ROOT_NAMESPACE,
          location: Util.dummy_location(source_map.filename)
        )

        helper_modules.each do |helper_module|
          pins << Util.build_module_include(
            example_group_pin,
            helper_module,
            example_group_pin.location
          )
        end

        pins
      end

      # @return [Config]
      def config
        self.class.config
      end

      # @param namespace_pins [Array<Pin::Namespace>]
      # @param line [Integer]
      # @return [Pin::Namespace, nil]
      def closest_namespace_pin(namespace_pins, line)
        namespace_pins.min_by do |namespace_pin|
          distance = line - namespace_pin.location.range.start.line
          distance >= 0 ? distance : Float::INFINITY
        end
      end

      # @param namespace [Pin::Namespace]
      # @param ast [Parser::AST::Node]
      # @param types [Array<String>, nil]
      # @return [Pin::Method, nil]
      def rspec_let_method(namespace, ast, types: nil)
        return unless ast.children
        return unless ast.children[2]&.children

        method_name = ast.children[2].children[0]&.to_s or return
        Util.build_public_method(
          namespace,
          method_name,
          types: types,
          location: Util.build_location(ast, namespace.filename),
          scope: :instance
        )
      end

      # @param namespace [Pin::Namespace]
      # @param ast [Parser::AST::Node]
      # @param described_class_name [String]
      # @return [Pin::Method, nil]
      def rspec_described_class_method(namespace, ast, described_class_name)
        Util.build_public_method(
          namespace,
          'described_class',
          types: ["Class<#{described_class_name}>"],
          location: Util.build_location(ast, namespace.filename),
          scope: :instance
        )
      end
    end
  end
end
