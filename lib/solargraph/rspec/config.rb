# frozen_string_literal: true

module Solargraph
  module Rspec
    # @example .solargraph.yml configuration for rspec
    #   rspec:
    #     let_methods:
    #       - let_it_be
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

      private

      # @return [Hash]
      def rspec_raw_data
        @rspec_raw_data ||= raw_data['rspec'] || {}
      end

      # @return [Array<Symbol>]
      def additional_let_methods
        (rspec_raw_data['let_methods'] || []).map(&:to_sym)
      end

      # @return [Array<Symbol>]
      def additional_example_methods
        (rspec_raw_data['example_methods'] || []).map(&:to_sym)
      end

      # @return [Hash]
      def raw_data
        @solargraph_config.raw_data
      end
    end
  end
end
