# frozen_string_literal: true

require_relative 'config'
require_relative 'walker'
require_relative 'util'

module Solargraph
  module Rspec
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

        walker = Rspec::Walker.from_source(source_map.source)
        # @type [Array<Pin::Base>]
        pins = []
        # @type [Array<Pin::Namespace>]
        namespace_pins = []
        # @type [Array<Pin::Block>]
        block_pins = []

        # Setup RSpec helpers
        example_group_pin = Solargraph::Pin::Namespace.new(
          name: 'RSpec::ExampleGroups',
          location: Util.dummy_location(source_map.filename)
        )
        ['RSpec::Matchers'].each do |helper_module|
          pins << Util.build_module_include(
            example_group_pin,
            helper_module,
            example_group_pin.location
          )
        end

        # Each describe/context block
        each_rspec_block(walker.ast, 'RSpec::ExampleGroups') do |namespace_name, ast|
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
        pins += namespace_pins
        pins += block_pins

        # @type [Pin::Method, nil]
        described_class_pin = nil
        rspec_const = ::Parser::AST::Node.new(:const, [nil, :RSpec])
        walker.on :send, [rspec_const, :describe, :any] do |ast|
          namespace_pin = closest_namespace_pin(namespace_pins, ast.loc.line)
          next unless namespace_pin

          described_class_pin = rspec_described_class_method(namespace_pin, ast)
          pins << described_class_pin unless described_class_pin.nil?
        end

        config.let_methods.each do |let_method|
          walker.on :send, [nil, let_method] do |ast|
            namespace_pin = closest_namespace_pin(namespace_pins, ast.loc.line)
            next unless namespace_pin

            pin = rspec_let_method(namespace_pin, ast)
            pins << pin unless pin.nil?
          end
        end

        # @type [Pin::Method, nil]
        subject_pin = nil
        walker.on :send, [nil, :subject] do |ast|
          namespace_pin = closest_namespace_pin(namespace_pins, ast.loc.line)
          next unless namespace_pin

          subject_pin = rspec_let_method(namespace_pin, ast)
          pins << subject_pin unless subject_pin.nil?
        end

        walker.walk

        # Implicit subject
        if !subject_pin && described_class_pin
          namespace_pin = closest_namespace_pin(namespace_pins, described_class_pin.location.range.start.line)
          described_class = described_class_pin.return_type.first.subtypes.first.name

          subject_pin = Util.build_public_method(
            namespace_pin,
            'subject',
            types: [described_class],
            location: described_class_pin.location,
            scope: :instance
          )
          pins << subject_pin
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

      # Find all describe/context blocks in the AST.
      # @param ast [Parser::AST::Node]
      # @yield [String, Parser::AST::Node]
      def each_rspec_block(ast, parent_namespace = 'RSpec::ExampleGroups', &block)
        return unless ast.is_a?(::Parser::AST::Node)

        is_a_block = ast.type == :block && ast.children[0].type == :send
        is_a_context = is_a_block && %i[describe context].include?(ast.children[0].children[1])
        namespace_name = parent_namespace

        if is_a_context
          description_node = ast.children[0].children[2]
          block_name = rspec_describe_class_name(description_node)
          if block_name
            namespace_name = "#{parent_namespace}::#{block_name}"
            block&.call(namespace_name, ast)
          end
        end

        ast.children.each { |child| each_rspec_block(child, namespace_name, &block) }
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

      # @param ast [Parser::AST::Node]
      # @return [String, nil]
      def rspec_describe_class_name(ast)
        if ast.type == :str
          string_to_const_name(ast)
        elsif ast.type == :const
          full_constant_name(ast).gsub('::', '')
        else
          Solargraph.logger.warn "[RSpec] Unexpected AST type #{ast.type}"
          nil
        end
      end

      # @param namespace [Pin::Namespace]
      # @param ast [Parser::AST::Node]
      # @return [Pin::Method, nil]
      def rspec_described_class_method(namespace, ast)
        class_ast = ast.children[2]
        return unless class_ast.type == :const

        class_name = full_constant_name(class_ast)

        Util.build_public_method(
          namespace,
          'described_class',
          types: ["Class<#{class_name}>"],
          location: Util.build_location(class_ast, namespace.filename),
          scope: :instance
        )
      end

      # @param ast [Parser::AST::Node]
      # @return [String]
      def full_constant_name(ast)
        raise 'Node is not a constant' unless ast.type == :const

        name = ast.children[1].to_s
        if ast.children[0].nil?
          name
        else
          "#{full_constant_name(ast.children[0])}::#{name}"
        end
      end

      # @see https://github.com/rspec/rspec-core/blob/1eeadce5aa7137ead054783c31ff35cbfe9d07cc/lib/rspec/core/example_group.rb#L862
      # @param ast [Parser::AST::Node]
      # @return [String]
      def string_to_const_name(string_ast)
        return unless string_ast.type == :str

        name = string_ast.children[0]
        return 'Anonymous'.dup if name.empty?

        # Convert to CamelCase.
        name = " #{name}"
        name.gsub!(/[^0-9a-zA-Z]+([0-9a-zA-Z])/) do
          match = ::Regexp.last_match[1]
          match.upcase!
          match
        end

        name.lstrip! # Remove leading whitespace
        name.gsub!(/\W/, '') # JRuby, RBX and others don't like non-ascii in const names

        # Ruby requires first const letter to be A-Z. Use `Nested`
        # as necessary to enforce that.
        name.gsub!(/\A([^A-Z]|\z)/, 'Nested\1')

        name
      end
    end
  end
end
