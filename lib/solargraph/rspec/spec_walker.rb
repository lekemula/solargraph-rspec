# frozen_string_literal: true

require_relative 'walker'

module Solargraph
  module Rspec
    # Simple wrapper around [Walker] that provides RSpec-specific events and context for [SpecWalker::BaseProcessor]s.
    class SpecWalker
      require_relative 'spec_walker/node_types'
      require_relative 'spec_walker/base_processor'
      require_relative 'spec_walker/full_constant_name'
      require_relative 'spec_walker/rspec_context_namespace'
      require_relative 'spec_walker/fake_let_method'
      require_relative 'spec_walker/node_processors/blocks_in_examples_processor'
      require_relative 'spec_walker/node_processors/context_block_processor'
      require_relative 'spec_walker/node_processors/let_method_processor'
      require_relative 'spec_walker/node_processors/subject_processor'
      require_relative 'spec_walker/node_processors/example_block_processor'
      require_relative 'spec_walker/node_processors/hook_block_processor'

      # @param source_map [SourceMap]
      # @param config [Config]
      def initialize(source_map:, config:)
        @source_map = source_map
        @config = config
        @walker = Walker.new(NodeTypes.to_rubocop_ast(source_map.source.node))
        @walker.context[:rspec_walker] = self
        @in_example_or_hook_depth = 0
        @handlers = {
          on_described_class: [],
          on_let_method: [],
          on_subject: [],
          on_each_context_block: [],
          on_example_block: [],
          on_hook_block: [],
          on_blocks_in_examples: []
        }
      end

      # @return [Config]
      attr_reader :config

      # @return [Array<String>]
      def namespace_stack
        @namespace_stack ||= [Rspec::ROOT_NAMESPACE]
      end

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
      # @yieldparam fake_method_ast [::Parser::AST::Node]
      # @return [void]
      def on_let_method(&block)
        @handlers[:on_let_method] << block
      end

      # @param block [Proc]
      # @yieldparam method_name [String]
      # @yieldparam location_range [Solargraph::Range]
      # @yieldparam fake_method_ast [::Parser::AST::Node]
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
        @walker.on_after_walk(&block)
      end

      # @return [void]
      def walk!
        @walker.walk!
      end

      # @param event [Symbol]
      # @param args [Array] Arguments to pass to event handlers
      # @return [void]
      def fire(event, *args)
        @handlers.fetch(event, []).each { |h| h.call(*args) }
      end

      # @return [Boolean]
      def in_example_or_hook?
        @in_example_or_hook_depth.positive?
      end

      # @return [void]
      def increment_example_depth!
        @in_example_or_hook_depth += 1
      end

      # @return [void]
      def decrement_example_depth!
        @in_example_or_hook_depth -= 1
      end
    end
  end
end
