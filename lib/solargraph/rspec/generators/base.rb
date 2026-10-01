# frozen_string_literal: true

require 'shellwords'

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

        # The shell command plus its parts, so clients can either run it in a terminal
        # or spawn rspec themselves (e.g. to batch several targets into one process).
        #
        # @param file_path [String]
        # @param line [Integer, nil] 0-indexed line number, or nil to run the whole file
        # @return [Hash{Symbol => String, Array<String>}]
        def build_rspec_command(file_path, line = nil)
          executable = config.use_bundler ? [config.bundler_path, 'exec', 'rspec'] : ['rspec']
          target = line ? "#{file_path}:#{line + 1}" : file_path
          { command: Shellwords.join(executable + [target]), executable: executable, target: target }
        end
      end
    end
  end
end
