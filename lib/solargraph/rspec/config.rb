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
        %i[let let!] + additional_let_methods
      end

      private

      def rspec_raw_data
        @rspec_raw_data ||= raw_data['rspec'] || {}
      end

      def additional_let_methods
        (rspec_raw_data['let_methods'] || []).map(&:to_sym)
      end

      # @return [Hash]
      def raw_data
        @solargraph_config.raw_data
      end
    end
  end
end
