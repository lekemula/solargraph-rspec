# frozen_string_literal: true

module Solargraph
  module Rspec
    class Walker
      # Base class for all node processors that handle AST traversal.
      # Subclasses register handlers for specific node types or patterns, which are invoked
      # during tree walking to fire events on the walker.
      class BaseProcessor
        extend RuboCop::AST::NodePattern::Macros

        class << self
          # @return [Hash{Symbol => Symbol, Proc}]
          def node_type_enter_handlers
            @node_type_enter_handlers ||= {}
          end

          # @return [Hash{Symbol => Symbol, Proc}]
          def node_type_leave_handlers
            @node_type_leave_handlers ||= {}
          end

          # @return [Array<Array(Symbol, Symbol, Proc)>]
          def node_pattern_enter_handlers
            @node_pattern_enter_handlers ||= []
          end

          # @return [Array<Array(Symbol, Symbol, Proc)>]
          def node_pattern_leave_handlers
            @node_pattern_leave_handlers ||= []
          end

          # Register a handler for entering nodes of a specific type.
          # @param type [Symbol] The RuboCop node type (e.g., :block, :send)
          # @param method_name [Symbol, nil] Method to call on handler invocation, or nil to use block
          # @return [void]
          def on_node_type(type, method_name = nil, &block)
            node_type_enter_handlers[type] = method_name || block
          end

          # Register a handler for leaving nodes of a specific type.
          # @param type [Symbol] The RuboCop node type
          # @param method_name [Symbol, nil] Method to call on handler invocation, or nil to use block
          # @return [void]
          def on_node_type_leave(type, method_name = nil, &block)
            node_type_leave_handlers[type] = method_name || block
          end

          # Register a handler for entering nodes matching an AST pattern.
          # @param pattern [String] RuboCop AST pattern matching syntax
          # @param method_name [Symbol, nil] Method to call on handler invocation, or nil to use block
          # @return [void]
          def on_node_pattern_enter(pattern, method_name = nil, &block)
            matcher_name = :"__pattern_enter_#{node_pattern_enter_handlers.size}"
            def_node_matcher matcher_name, pattern
            node_pattern_enter_handlers << [matcher_name, method_name || block]
          end

          # Register a handler for leaving nodes matching an AST pattern.
          # @param pattern [String] RuboCop AST pattern matching syntax
          # @param method_name [Symbol, nil] Method to call on handler invocation, or nil to use block
          # @return [void]
          def on_node_pattern_leave(pattern, method_name = nil, &block)
            matcher_name = :"__pattern_leave_#{node_pattern_leave_handlers.size}"
            def_node_matcher matcher_name, pattern
            node_pattern_leave_handlers << [matcher_name, method_name || block]
          end

          def inherited(subclass)
            super
            Walker.register_processor(subclass)
          end
        end

        # @return [Solargraph::Rspec::Walker]
        attr_reader :walker

        # @param walker [Solargraph::Rspec::Walker]
        def initialize(walker)
          @walker = walker
        end

        # Dispatch enter handlers for a given node to all registered handlers.
        # @param node [RuboCop::AST::Node]
        # @return [void]
        def dispatch_enter(node)
          return unless node.is_a?(RuboCop::AST::Node)

          call_handler(node, self.class.node_type_enter_handlers[node.type])
          self.class.node_pattern_enter_handlers.each do |matcher_name, handler|
            call_handler(node, handler) if send(matcher_name, node)
          end
        end

        # Dispatch leave handlers for a given node to all registered handlers.
        # @param node [RuboCop::AST::Node]
        # @return [void]
        def dispatch_leave(node)
          return unless node.is_a?(RuboCop::AST::Node)

          call_handler(node, self.class.node_type_leave_handlers[node.type])
          self.class.node_pattern_leave_handlers.each do |matcher_name, handler|
            call_handler(node, handler) if send(matcher_name, node)
          end
        end

        private

        # Invoke a handler with the given node.
        # @param node [RuboCop::AST::Node]
        # @param handler [Symbol, Proc, nil]
        # @return [void]
        def call_handler(node, handler)
          return unless handler

          handler.is_a?(Symbol) ? send(handler, node) : instance_exec(node, &handler)
        end
      end
    end
  end
end
