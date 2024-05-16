
# frozen_string_literal: true

module Solargraph
  module Rspec
    class RubyVMWalker
      class Hook
        attr_reader :node_type

        # @param node_type [Symbol]
        # @param args [Array]
        # @param block [Proc]
        def initialize(node_type, args, &block)
          @node_type = node_type
          @args = args
          @proc = Proc.new(&block)
        end

        # @param node [RubyVM::AbstractSyntaxTree::Node]
        # @return [void]
        def visit(node)
          return unless matches?(node)

          if @proc.arity == 1
            @proc.call(node)
          elsif @proc.arity == 2
            walker = Walker.new(node)
            @proc.call(node, walker)
            walker.walk
          end
        end

        private

        # @param node [RubyVM::AbstractSyntaxTree::Node]
        # @return [Boolean]
        def matches?(node)
          return false unless node.type == node_type
          return false unless node.children
          return true if @args.empty?

          a_child_matches = node.children.first.is_a?(RubyVM::AbstractSyntaxTree::Node) && node.children.any? do |child|
            child.is_a?(RubyVM::AbstractSyntaxTree::Node) &&
              match_children(child.children, @args[1..])
          end

          return true if a_child_matches

          match_children(node.children)
        end

        # @param children [Array<RubyVM::AbstractSyntaxTree::Node>]
        def match_children(children, args = @args)
          args.each_with_index.all? do |arg, i|
            if arg == :any
              true
            elsif children[i].is_a?(RubyVM::AbstractSyntaxTree::Node) && arg.is_a?(Symbol)
              children[i].type == arg
            else
              children[i] == arg
            end
          end
        end
      end

      def self.normalize_ast(source)
        ast = RubyVM::AbstractSyntaxTree.parse(source.code)
        raise "Parsing error" unless ast

        ast
      end

      def self.from_source(source)
        new(normalize_ast(source))
      end

      attr_reader :ast
      attr_reader :comments

      def initialize(ast, comments = {})
        @comments = comments
        @ast = ast
        @hooks = Hash.new([])
      end

      def on(node_type, args = [], &block)
        @hooks[node_type] << Hook.new(node_type, args, &block)
      end

      def walk
        @ast.is_a?(Array) ? @ast.each { |node| traverse(node) } : traverse(@ast)
      end

      private

      def traverse(node)
        return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)

        @hooks[node.type].each { |hook| hook.visit(node) }

        node.children.each { |child| traverse(child) }
      end
    end
  end
end
