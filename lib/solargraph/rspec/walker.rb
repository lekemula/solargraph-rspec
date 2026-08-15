# frozen_string_literal: true

module Solargraph
  module Rspec
    # Generic AST walker with a processor registry.
    # Subclasses add domain-specific setup around {#walk!}.
    class Walker
      class << self
        # @return [Array<Class>]
        def processor_classes
          @processor_classes ||= []
        end

        # @param klass [Class]
        # @return [void]
        def register_processor(klass)
          processor_classes << klass
        end
      end

      # @param ast [RuboCop::AST::Node, nil]
      def initialize(ast = nil)
        @ast = ast
      end

      # @return [Hash]
      def context
        @context ||= {}
      end

      # Register a callback to be called after the walk completes.
      # @return [void]
      def on_after_walk(&block)
        (@after_walk_handlers ||= []) << block
      end

      # Walk the AST, dispatching enter/leave events to all registered processors.
      # @return [void]
      def walk!
        return unless @ast

        @processors = Walker.processor_classes.map { |klass| klass.new(self) }
        walk(@ast)
        (@after_walk_handlers ||= []).each(&:call)
      end

      private

      # @param node [RuboCop::AST::Node]
      # @return [void]
      def walk(node)
        return unless node.is_a?(::RuboCop::AST::Node)

        @processors&.each { |p| p.dispatch_enter(node) }
        node.each_child_node { |child| walk(child) }
        @processors&.each { |p| p.dispatch_leave(node) }
      end
    end
  end
end

require_relative 'walker/base_processor'
