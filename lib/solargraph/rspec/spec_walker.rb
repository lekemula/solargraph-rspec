# frozen_string_literal: true

require_relative 'walker'

module Solargraph
  module Rspec
    class SpecWalker
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
        each_context_block(@walker.ast, Rspec::ROOT_NAMESPACE) do |namespace_name, ast|
          @handlers[:on_each_context_block].each do |handler|
            handler.call(namespace_name, ast)
          end
        end

        rspec_const = ::Parser::AST::Node.new(:const, [nil, :RSpec])
        walker.on :send, [rspec_const, :describe, :any] do |ast|
          @handlers[:on_described_class].each do |handler|
            class_ast = ast.children[2]
            next unless class_ast

            class_name = full_constant_name(class_ast)
            handler.call(class_ast, class_name)
          end
        end

        config.let_methods.each do |let_method|
          walker.on :send, [nil, let_method] do |ast|
            @handlers[:on_let_method].each do |handler|
              handler.call(ast)
            end
          end
        end

        walker.on :send, [nil, :subject] do |ast|
          @handlers[:on_subject].each do |handler|
            handler.call(ast)
          end
        end

        walker.on :block do |block_ast|
          next if block_ast.children.first.type != :send

          method_ast = block_ast.children.first
          method_name = method_ast.children[1]
          next unless Rspec::EXAMPLE_METHODS.include?(method_name.to_s)

          @handlers[:on_example_block].each do |handler|
            handler.call(block_ast)
          end

          # @param blocks_in_examples [Parser::AST::Node]
          each_block(block_ast.children[2]) do |blocks_in_examples|
            @handlers[:on_blocks_in_examples].each do |handler|
              handler.call(blocks_in_examples)
            end
          end
        end

        walker.on :block do |block_ast|
          next if block_ast.children.first.type != :send

          method_ast = block_ast.children.first
          method_name = method_ast.children[1]
          next unless Rspec::HOOK_METHODS.include?(method_name.to_s)

          @handlers[:on_hook_block].each do |handler|
            handler.call(block_ast)
          end

          # @param blocks_in_examples [Parser::AST::Node]
          each_block(block_ast.children[2]) do |blocks_in_examples|
            @handlers[:on_blocks_in_examples].each do |handler|
              handler.call(blocks_in_examples)
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
        return unless ast.is_a?(::Parser::AST::Node)

        is_a_block = ast.type == :block && ast.children[0].type == :send

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
          is_a_context = %i[describe context].include?(block_ast.children[0].children[1])

          next unless is_a_context

          description_node = block_ast.children[0].children[2]
          block_name = rspec_describe_class_name(description_node)
          next unless block_name

          parent_namespace = namespace_name = "#{parent_namespace}::#{block_name}"
          block&.call(namespace_name, block_ast)
          next parent_namespace
        end
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
