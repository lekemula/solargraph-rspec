# frozen_string_literal: true

module Solargraph
  module Rspec
    module Generators
      # Generates LSP code lenses from RSpec DSL constructs
      # @abstract
      class Base
        # @return [Solargraph::Rspec::SpecWalker]
        attr_reader :rspec_walker

        # @return [Solargraph::Rspec::Config]
        attr_reader :config

        # @return [Array<Solargraph::CodeLens>]
        attr_reader :code_lenses

        # @param rspec_walker [Solargraph::Rspec::SpecWalker]
        # @param config [Solargraph::Rspec::Config]
        # @param code_lenses [Array<Solargraph::CodeLens>]
        def initialize(rspec_walker:, config:, code_lenses: [])
          @rspec_walker = rspec_walker
          @config = config
          @code_lenses = code_lenses
        end

        # @param _source_map [Solargraph::SourceMap]
        # @return [void]
        def generate(_source_map)
          raise NotImplementedError
        end

        private

        # @param lens [Solargraph::CodeLens]
        # @return [void]
        def add_code_lens(lens)
          code_lenses.push(lens)
        end

        # @param file_path [String]
        # @param line [Integer] 0-indexed line number
        # @return [String]
        def build_rspec_command(file_path, line)
          target = "#{file_path}:#{line + 1}"
          if config.use_bundler
            "#{config.bundler_path} exec rspec #{target}"
          else
            "rspec #{target}"
          end
        end
      end
    end
  end
end
