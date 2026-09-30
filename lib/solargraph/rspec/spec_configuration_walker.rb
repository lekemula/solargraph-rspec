# frozen_string_literal: true

require_relative 'walker'
require_relative 'spec_walker/full_constant_name'

module Solargraph
  module Rspec
    # Walks AST to find RSpec.configure blocks and extract included modules
    class SpecConfigurationWalker
      # @param ast [::Parser::AST::Node]
      # @param filename [String] The file being parsed
      def initialize(ast, filename)
        @ast = ast
        @filename = filename
        @walker = Walker.new(ast)
        @included_modules = []
      end

      # Represents a module included via config.include in RSpec.configure
      # @param node [::Parser::AST::Node] The AST node for the include call
      # @param file [String] The file where this module is included
      # @param module_name [String] The fully qualified name of the included module
      class IncludedModule < Struct.new(:node, :file, :module_name)
      end

      # Walk the AST and extract included modules
      # @return [Array<IncludedModule>]
      def extract_included_modules
        @walker.on :block, [:send] do |node|
          send_node = node.children[0]
          send_receiver = send_node.children[0]

          # Check if this is RSpec.configure
          next unless send_receiver&.type == :const
          next unless send_receiver.children[1] == :RSpec
          next unless send_node.children[1] == :configure

          # Ensure block has arguments (the config parameter)
          next if node.children[1].children.empty?

          process_configure_block(node)
        end

        @walker.walk
        @included_modules
      end

      private

      # Process the RSpec.configure block to find config.include calls
      # @param configure_block [::Parser::AST::Node]
      # @return [void]
      def process_configure_block(configure_block)
        # Get the config variable name (e.g., |config| or |c|)
        config_name = configure_block.children[1].children[0].children[0]

        config_walker = Walker.new(configure_block)
        config_walker.on :send, [:lvar, config_name] do |include_node|
          # Look for config.include calls
          next unless include_node.children[1] == :include

          mod_node = include_node.children[2]
          next unless mod_node.is_a?(::Parser::AST::Node)
          next unless mod_node.type == :const

          module_name = SpecWalker::FullConstantName.from_ast(mod_node)
          @included_modules << IncludedModule.new(include_node, @filename, module_name)
        end

        config_walker.walk
      end
    end
  end
end
