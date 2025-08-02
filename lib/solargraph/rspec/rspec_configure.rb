# frozen_string_literal: true

module Solargraph
  module Rspec
    # RSpec.configure ... config.include handler, essentially
    class RSpecConfigure
      COMMON_HELPER_FILES = [
        'spec/spec_helper.rb',
        'spec/rails_helper.rb'
      ].freeze

      # @param node [::Parser::AST::Node]
      # @param file [String] The name of the file this is module is defined in
      # @param module_name [String] The name of the module to be included
      class IncludedModule < Struct.new(:node, :file, :module_name) do
      end

      def self.instance
        @instance ||= new
      end

      def self.reset
        @instance = nil
      end

      # @return [Array<Solargraph::Pin::Reference::Include>]
      def pins
        ns = Solargraph::Pin::Namespace.new(name: 'RSpec::ExampleGroups')

        included_modules.map do |m|
          Solargraph::Pin::Reference::Include.new(
            closure: ns,
            name: m.module_name,
            location: Solargraph::Location.new(m.file, Solargraph::Parser.node_range(m.node))
          )
        end
      end

      def extra_requires
        included_modules.map(&:file).uniq + Dir['spec/support/**/*.rb']
      end

      # @return [Array<IncludedModule>]
      def included_modules
        @included_modules ||= parse_included_modules
      end

      private

      # @return [Array<IncludedModule>]
      def parse_included_modules
        modules = []

        COMMON_HELPER_FILES.each do |f|
          ast = Solargraph::Parser.parse(File.read(f), f)
          modules += extract_included_modules(ast, f)
        rescue Errno::ENOENT
          # Ignore this error - no file means we can chill
        rescue StandardError => e
          Solargraph.logger.error("[RSpec] [RSpecConfigure] Can't read helper file '#{f}': #{e}")
        end

        modules
      end

      # Parses the modules that were included int he Rspec.configure (in common helper files)
      # @param ast [Parser::AST::Node]
      # @param file [String]
      #
      # @return [Array<IncludedModule>]
      def extract_included_modules(ast, file)
        walker = Walker.new(ast)

        # @type [Array<IncludedModule>]
        included_modules = []

        walker.on :block, [:send] do |node|
          send_node = node.children[0]
          send_receiver = send_node.children[0]

          next if send_receiver.type != :const || send_receiver.children[2] == :Rspec
          next unless send_node.children[1] == :configure
          # No args
          next if node.children[1].children.empty?

          config_name = node.children[1].children[0].children[0]
          config_walker = Walker.new(node)
          config_walker.on :send, [:lvar, config_name] do |include_node|
            next unless include_node.children[1] == :include

            mod_node = include_node.children[2]
            next unless mod_node.is_a? ::Parser::AST::Node
            next unless mod_node.type == :const

            included_modules << IncludedModule.new(
              include_node, file, SpecWalker::FullConstantName.from_ast(mod_node)
            )
          end

          config_walker.walk
        end

        walker.walk

        included_modules
      end
    end
  end
end
