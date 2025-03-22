# frozen_string_literal: true

require_relative 'walker'
require_relative 'spec_walker/node_types'
require_relative 'spec_walker/full_constant_name'
require_relative 'spec_walker/rspec_context_namespace'
require_relative 'spec_walker/fake_let_method'

module Solargraph
  module Rspec
    class SpecWalker
      # @param source_map [SourceMap]
      # @param config [Config]
      def initialize(source_map:, config:)
        @source_map = source_map
        @config = config
        # TODO: Implement SpecWalker with parser gem using default AST from `source_map.source.node`
        @walker = Rspec::Walker.new(ruby_vm_node(source_map))
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
      # @yieldparam class_name [String]
      # @yieldparam location_range [Solargraph::Range]
      # @return [void]
      def on_described_class(&block)
        @handlers[:on_described_class] << block
      end

      # @param block [Proc]
      # @yieldparam method_name [String]
      # @yieldparam location_range [Solargraph::Range]
      # @yieldparam fake_method_ast [RubyVM::AbstractSyntaxTree::Node]
      # @return [void]
      def on_let_method(&block)
        @handlers[:on_let_method] << block
      end

      # @param block [Proc]
      # @yieldparam method_name [String]
      # @yieldparam location_range [Solargraph::Range]
      # @yieldparam fake_method_ast [RubyVM::AbstractSyntaxTree::Node]
      # @return [void]
      def on_subject(&block)
        @handlers[:on_subject] << block
      end

      # @param block [Proc]
      # @yieldparam namespace_name [String]
      # @yieldparam location_range [Solargraph::Range]
      # @return [void]
      def on_each_context_block(&block)
        @handlers[:on_each_context_block] << block
      end

      #
      # @param block [Proc]
      # @yieldparam location_range [Solargraph::Range]
      # @return [void]
      def on_example_block(&block)
        @handlers[:on_example_block] << block
      end

      # @param block [Proc]
      # @yieldparam location_range [Solargraph::Range]
      # @return [void]
      def on_hook_block(&block)
        @handlers[:on_hook_block] << block
      end

      # @param block [Proc]
      # @yieldparam location_range [Solargraph::Range]
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

          fake_method_ast = FakeLetMethod.transform_block(block_ast, @source_map.source.code, method_name)

          @handlers[:on_let_method].each do |handler|
            handler.call(method_name, PinFactory.build_location_range(block_ast.children[0]), fake_method_ast)
          end
        end

        walker.on :ITER do |block_ast|
          next unless NodeTypes.a_subject_block?(block_ast)

          method_name = NodeTypes.let_method_name(block_ast)
          fake_method_ast = FakeLetMethod.transform_block(block_ast, @source_map.source.code, method_name || 'subject')

          @handlers[:on_subject].each do |handler|
            handler.call(method_name, PinFactory.build_location_range(block_ast.children[0]), fake_method_ast)
          end
        end

        walker.on :ITER do |block_ast|
          next unless NodeTypes.a_example_block?(block_ast, config)

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

          # @HACK: When we describe `SomeClass` without a namespace, Solargraph confuses described_class with the
          # `RSpec::ExampleGroups::SomeClass` constant. To avoid this, we append the root namespace with "Test"
          block_name = "Test#{block_name}" if parent_namespace == Rspec::ROOT_NAMESPACE

          parent_namespace = namespace_name = "#{parent_namespace}::#{block_name}"
          block&.call(namespace_name, block_ast)
          next parent_namespace
        end
      end

      # @param source_map [SourceMap]
      # @return [RubyVM::AbstractSyntaxTree::Node]
      def ruby_vm_node(source_map)
        RubyVM::AbstractSyntaxTree.parse(source_map.source.code)
      end
    end
  end
end
