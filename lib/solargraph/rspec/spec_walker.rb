# frozen_string_literal: true

require_relative 'walker'

module Solargraph
  module Rspec
    class SpecWalker
      class NodeTypes
        # @param ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [Boolean]
        def self.a_block?(ast)
          return false unless ast.is_a?(RubyVM::AbstractSyntaxTree::Node)

          %i[ITER LAMBDA].include?(ast.type)
        end

        # @param ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [Boolean]
        def self.a_context_block?(block_ast)
          Solargraph::Rspec::CONTEXT_METHODS.include?(method_with_block_name(block_ast))
        end

        # @param ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [Boolean]
        def self.a_subject_block?(block_ast)
          Solargraph::Rspec::SUBJECT_METHODS.include?(method_with_block_name(block_ast))
        end

        # @param ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [Boolean]
        def self.a_example_block?(block_ast)
          Solargraph::Rspec::EXAMPLE_METHODS.include?(method_with_block_name(block_ast))
        end

        # @param ast [RubyVM::AbstractSyntaxTree::Node]
        # @param config [Config]
        # @return [Boolean]
        def self.a_let_block?(block_ast, config)
          config.let_methods.map(&:to_s).include?(method_with_block_name(block_ast))
        end

        # @param ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [Boolean]
        def self.a_hook_block?(block_ast)
          Solargraph::Rspec::HOOK_METHODS.include?(method_with_block_name(block_ast))
        end

        def self.a_constant?(ast)
          %i[CONST COLON2].include?(ast.type)
        end

        # @param block_ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [String, nil]
        def self.method_with_block_name(block_ast)
          return nil unless a_block?(block_ast)

          method_call = %i[CALL FCALL].include?(block_ast.children[0].type)
          return nil unless method_call

          block_ast.children[0].children.select { |child| child.is_a?(Symbol) }.first&.to_s
        end

        # @param block_ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [RubyVM::AbstractSyntaxTree::Node]
        def self.context_description_node(block_ast)
          case block_ast.children[0].type
          when :CALL # RSpec.describe "something" do end
            block_ast.children[0].children[2].children[0]
          when :FCALL # describe "something" do end
            block_ast.children[0].children[1].children[0]
          end
        end

        # @param block_ast [RubyVM::AbstractSyntaxTree::Node]
        # @return [String]
        def self.let_method_name(block_ast)
          block_ast.children[0].children[1]&.children&.[](0)&.children&.[](0)&.to_s
        end
      end

      class FullConstantName
        class << self
          # @param ast [RubyVM::AbstractSyntaxTree::Node]
          # @return [String]
          def from_ast(ast)
            raise 'Node is not a constant' unless NodeTypes.a_constant?(ast)

            if ast.type == :CONST
              ast.children[0].to_s
            elsif ast.type == :COLON2
              name = ast.children[1].to_s
              "#{from_ast(ast.children[0])}::#{name}"
            end
          end

          def from_context_block_ast(block_ast)
            ast = NodeTypes.context_description_node(block_ast)
            from_ast(ast)
          end
        end
      end

      class RspecContextNamespace
        class << self
          # @param block_ast [RubyVM::AbstractSyntaxTree::Node]
          # @return [String, nil]
          def from_block_ast(block_ast)
            return unless block_ast.is_a?(RubyVM::AbstractSyntaxTree::Node)

            ast = NodeTypes.context_description_node(block_ast)
            if ast.type == :STR
              string_to_const_name(ast)
            elsif NodeTypes.a_constant?(ast)
              FullConstantName.from_ast(ast).gsub('::', '')
            else
              Solargraph.logger.warn "[RSpec] Unexpected AST type #{ast.type}"
              nil
            end
          end

          private

          # @see https://github.com/rspec/rspec-core/blob/1eeadce5aa7137ead054783c31ff35cbfe9d07cc/lib/rspec/core/example_group.rb#L862
          # @param ast [Parser::AST::Node]
          # @return [String]
          def string_to_const_name(string_ast)
            return unless string_ast.type == :STR

            name = string_ast.children[0]
            return 'Anonymous'.dup if name.empty?

            # Convert to CamelCase.
            name = +" #{name}"
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

      # @param source_map [SourceMap]
      # @param config [Config]
      def initialize(source_map:, config:)
        @source_map = source_map
        @config = config
        @walker = Rspec::Walker.from_source(source_map.source)
        @handlers = {
          on_described_class: [],
          on_let_method: [],
          on_subject: [],
          on_each_context_block: [],
          on_example_block: [],
          on_hook_block: [],
          on_blocks_in_examples: [],
          after_walk: []
        }
      end

      # @return [Walker]
      attr_reader :walker

      # @return [Config]
      attr_reader :config

      # @param block [Proc]
      # @return [void]
      def on_described_class(&block)
        @handlers[:on_described_class] << block
      end

      # @param block [Proc]
      # @return [void]
      def on_let_method(&block)
        @handlers[:on_let_method] << block
      end

      # @param block [Proc]
      # @return [void]
      def on_subject(&block)
        @handlers[:on_subject] << block
      end

      # @param block [Proc]
      # @return [void]
      def on_each_context_block(&block)
        @handlers[:on_each_context_block] << block
      end

      #
      # @param block [Proc]
      # @return [void]
      def on_example_block(&block)
        @handlers[:on_example_block] << block
      end

      # @param block [Proc]
      # @return [void]
      def on_hook_block(&block)
        @handlers[:on_hook_block] << block
      end

      # @param block [Proc]
      # @return [void]
      def on_blocks_in_examples(&block)
        @handlers[:on_blocks_in_examples] << block
      end

      # @param block [Proc]
      # @return [void]
      def after_walk(&block)
        @handlers[:after_walk] << block
      end

      # @return [void]
      def walk!
        each_context_block(@walker.ast, Rspec::ROOT_NAMESPACE) do |namespace_name, block_ast|
          desc_node = NodeTypes.context_description_node(block_ast)

          @handlers[:on_each_context_block].each do |handler|
            handler.call(namespace_name, PinFactory.build_location_range(block_ast))
          end

          if NodeTypes.a_constant?(desc_node) # rubocop:disable Style/Next
            @handlers[:on_described_class].each do |handler|
              class_name_ast = NodeTypes.context_description_node(block_ast)
              class_name = FullConstantName.from_ast(class_name_ast)
              handler.call(class_name, PinFactory.build_location_range(class_name_ast))
            end
          end
        end

        walker.on :ITER do |block_ast|
          next unless NodeTypes.a_let_block?(block_ast, config)

          method_name = NodeTypes.let_method_name(block_ast)
          next unless method_name

          @handlers[:on_let_method].each do |handler|
            handler.call(method_name, PinFactory.build_location_range(block_ast.children[0]))
          end
        end

        walker.on :ITER do |block_ast|
          next unless NodeTypes.a_subject_block?(block_ast)

          method_name = NodeTypes.let_method_name(block_ast)

          @handlers[:on_subject].each do |handler|
            handler.call(method_name, PinFactory.build_location_range(block_ast.children[0]))
          end
        end

        walker.on :ITER do |block_ast|
          next unless NodeTypes.a_example_block?(block_ast)

          @handlers[:on_example_block].each do |handler|
            handler.call(PinFactory.build_location_range(block_ast))
          end

          # @param blocks_in_examples [RubyVM::AbstractSyntaxTree::Node]
          each_block(block_ast.children[1]) do |blocks_in_examples|
            @handlers[:on_blocks_in_examples].each do |handler|
              handler.call(PinFactory.build_location_range(blocks_in_examples))
            end
          end
        end

        walker.on :ITER do |block_ast|
          next unless NodeTypes.a_hook_block?(block_ast)

          @handlers[:on_hook_block].each do |handler|
            handler.call(PinFactory.build_location_range(block_ast))
          end

          # @param blocks_in_examples [RubyVM::AbstractSyntaxTree::Node]
          each_block(block_ast.children[1]) do |blocks_in_examples|
            @handlers[:on_blocks_in_examples].each do |handler|
              handler.call(PinFactory.build_location_range(blocks_in_examples))
            end
          end
        end

        walker.walk

        @handlers[:after_walk].each(&:call)
      end

      private

      # @param ast [Parser::AST::Node]
      # @param parent_result [Object]
      def each_block(ast, parent_result = nil, &block)
        return unless ast.is_a?(RubyVM::AbstractSyntaxTree::Node)

        is_a_block = NodeTypes.a_block?(ast)

        if is_a_block
          result = block&.call(ast, parent_result)
          parent_result = result if result
        end

        ast.children.each { |child| each_block(child, parent_result, &block) }
      end

      # Find all describe/context blocks in the AST.
      # @param ast [Parser::AST::Node]
      # @yield [String, Parser::AST::Node]
      def each_context_block(ast, root_namespace = Rspec::ROOT_NAMESPACE, &block)
        each_block(ast, root_namespace) do |block_ast, parent_namespace|
          is_a_context = NodeTypes.a_context_block?(block_ast)

          next unless is_a_context

          block_name = RspecContextNamespace.from_block_ast(block_ast)
          next unless block_name

          parent_namespace = namespace_name = "#{parent_namespace}::#{block_name}"
          block&.call(namespace_name, block_ast)
          next parent_namespace
        end
      end
    end
  end
end
