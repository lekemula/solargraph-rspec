# frozen_string_literal: true

#
# Credits: This file was originally copied and adapted from the solargraph-rails gem

module Solargraph
  module Rspec
    class Walker
      class ParsingError < StandardError; end

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

        # @param node [::Parser::AST::Node]
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

        # @param node [::Parser::AST::Node]
        # @return [Boolean]
        def matches?(node)
          return false unless node.type == node_type
          return false unless node.children
          return true if @args.empty?

          a_child_matches = node.children.first.is_a?(::Parser::AST::Node) && node.children.any? do |child|
            child.is_a?(::Parser::AST::Node) &&
              match_children(child.children, @args[1..])
          end

          return true if a_child_matches

          match_children(node.children)
        end

        # @param children [Array<::Parser::AST::Node>]
        def match_children(children, args = @args)
          args.each_with_index.all? do |arg, i|
            if arg == :any
              true
            elsif children[i].is_a?(::Parser::AST::Node) && arg.is_a?(Symbol)
              children[i].type == arg
            else
              children[i] == arg
            end
          end
        end
      end

      attr_reader :ast, :comments

      # @param ast [::Parser::AST::Node]
      # @param comments [Hash]
      def initialize(ast, comments = {})
        @comments = comments
        @ast = ast
        @hooks = Hash.new { |h, k| h[k] = [] }
      end

      # @yieldparam [::Parser::AST::Node]
      # @yieldparam [Walker]
      def on(node_type, args = [], &block)
        @hooks[node_type] << Hook.new(node_type, args, &block)
      end

      def walk
        @ast.is_a?(Array) ? @ast.each { |node| traverse(node) } : traverse(@ast)
      end

      private

      def traverse(node)
        return unless node.is_a?(::Parser::AST::Node)

        @hooks[node.type].each { |hook| hook.visit(node) }

        node.children.each { |child| traverse(child) }
      end
    end
  end
end
