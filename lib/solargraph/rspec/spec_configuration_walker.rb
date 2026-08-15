# frozen_string_literal: true

require_relative 'spec_walker/full_constant_name'
require_relative 'spec_walker/node_types'

module Solargraph
  module Rspec
    # Walks AST to find RSpec.configure blocks and extract included modules
    class SpecConfigurationWalker
      RSPEC_CONFIGURE_BLOCK = RuboCop::AST::NodePattern.new(<<~PATTERN)
        (block
          (send (const {nil? cbase} :RSpec) :configure)
          (args (arg $_))
          ...)
      PATTERN

      CONFIG_INCLUDE_CALL = RuboCop::AST::NodePattern.new(<<~PATTERN)
        (send (lvar $_) :include (const ...))
      PATTERN

      # @param ast [::Parser::AST::Node]
      # @param filename [String] The file being parsed
      def initialize(ast, filename)
        @filename = filename
        @ast = SpecWalker::NodeTypes.to_rubocop_ast(ast)
        @included_modules = []
      end

      # Represents a module included via config.include in RSpec.configure
      IncludedModule = Struct.new(:node, :file, :module_name)

      # Walk the AST and extract included modules
      # @return [Array<IncludedModule>]
      def extract_included_modules
        return @included_modules unless @ast

        each_node(@ast, :block) do |node|
          config_var_name = RSPEC_CONFIGURE_BLOCK.match(node)
          next unless config_var_name

          process_configure_block(node, config_var_name)
        end

        @included_modules
      end

      private

      # Process the RSpec.configure block to find config.include calls
      # @param configure_block [RuboCop::AST::Node]
      # @param config_name [Symbol]
      # @return [void]
      def process_configure_block(configure_block, config_name)
        each_node(configure_block, :send) do |send_node|
          captured_var = CONFIG_INCLUDE_CALL.match(send_node)
          next unless captured_var == config_name

          mod_node = send_node.children[2]
          module_name = SpecWalker::FullConstantName.from_ast(mod_node)
          @included_modules << IncludedModule.new(send_node, @filename, module_name)
        end
      end

      # @param ast [RuboCop::AST::Node]
      # @param type [Symbol, nil]
      # @yieldparam node [RuboCop::AST::Node]
      def each_node(ast, type = nil, &block)
        return unless ast.is_a?(::RuboCop::AST::Node)

        yield ast if type.nil? || ast.type == type
        ast.children.each { |child| each_node(child, type, &block) }
      end
    end
  end
end
