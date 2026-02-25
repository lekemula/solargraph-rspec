# frozen_string_literal: true

require_relative 'spec_configuration_walker'
require_relative 'pin_factory'

module Solargraph
  module Rspec
    # Handles RSpec.configure ... config.include parsing
    # Provides pins for modules included globally via RSpec.configure
    class RSpecConfigure
      # @param config [Config]
      # @param root_namespace_pin [Solargraph::Pin::Namespace]
      def initialize(config:, root_namespace_pin:)
        @config = config
        @root_namespace_pin = root_namespace_pin
        @included_modules = nil
      end

      # @return [Array<Solargraph::Pin::Reference::Include>]
      def pins
        included_modules.map do |mod|
          Solargraph::Pin::Reference::Include.new(
            closure: @root_namespace_pin,
            name: mod.module_name,
            location: Solargraph::Location.new(mod.file, Solargraph::Parser.node_range(mod.node))
          )
        end
      end

      # @return [Array<String>]
      def extra_requires
        included_modules.map(&:file).uniq + support_files
      end

      # @return [Array<SpecConfigurationWalker::IncludedModule>]
      def included_modules
        @included_modules ||= parse_included_modules
      end

      private

      # @return [Array<String>]
      def support_files
        Dir['spec/support/**/*.rb']
      end

      # @return [Array<SpecConfigurationWalker::IncludedModule>]
      def parse_included_modules
        modules = []

        @config.config_helper_files.each do |file_path|
          ast = Solargraph::Parser.parse(File.read(file_path), file_path)
          walker = SpecConfigurationWalker.new(ast, file_path)
          modules += walker.extract_included_modules
        rescue Errno::ENOENT
          # Ignore missing files - they may not exist in all projects
        rescue StandardError => e
          Solargraph.logger.error(
            "[RSpec] [RSpecConfigure] Error reading helper file '#{file_path}': #{e.message}"
          )
        end

        modules
      end
    end
  end
end
