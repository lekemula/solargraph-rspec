# frozen_string_literal: true

module Solargraph
  module Rspec
    # @example .solargraph.yml configuration for rspec
    #   rspec:
    #     let_methods:
    #       - let_it_be
    #     config_helper_files:
    #       - spec/spec_helper.rb
    #       - spec/rails_helper.rb
    class Config
      def initialize(solargraph_config = Solargraph::Workspace::Config.new('./'))
        @solargraph_config = solargraph_config
        Solargraph.logger.debug "[RSpec] Solargraph config: #{raw_data}"
      end

      # @return [Solargraph::Workspace::Config]
      attr_reader :solargraph_config

      # @return [Array<Symbol>]
      def let_methods
        (Rspec::LET_METHODS + additional_let_methods).map(&:to_sym)
      end

      # @return [Array<Symbol>]
      def example_methods
        (Rspec::EXAMPLE_METHODS + additional_example_methods).map(&:to_sym)
      end

      # @return [Array<String>]
      def config_helper_files
        DEFAULT_CONFIG_HELPER_FILES + additional_config_helper_files
      end

      # @return [Boolean]
      def use_bundler
        rspec_raw_data.fetch('use_bundler', false)
      end

      # @return [String]
      def bundler_path
        rspec_raw_data.fetch('bundler_path', 'bundle')
      end

      private

      DEFAULT_CONFIG_HELPER_FILES = [
        'spec/spec_helper.rb',
        'spec/rails_helper.rb'
      ].freeze

      # @return [Hash]
      def rspec_raw_data
        @rspec_raw_data ||= raw_data['rspec'] || {}
      end

      # @return [Array<Symbol>]
      def additional_let_methods
        # @type [Array<String>, nil]
        let_methods = rspec_raw_data['let_methods']
        (let_methods || []).map(&:to_sym)
      end

      # @return [Array<Symbol>]
      def additional_example_methods
        # @type [Array<String>, nil]
        example_methods = rspec_raw_data['example_methods']
        (example_methods || []).map(&:to_sym)
      end

      # @return [Array<String>]
      def additional_config_helper_files
        # @type [Array<String>, nil]
        config_files = rspec_raw_data['config_helper_files']
        config_files || []
      end

      # @return [Hash]
      def raw_data
        @solargraph_config.raw_data
      end
    end
  end
end
