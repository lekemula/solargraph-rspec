# frozen_string_literal: true

require_relative 'base'

module Solargraph
  module Rspec
    module Generators
      # Generates a "Run RSpec" code lens for each describe/context/example block
      class CodeLensGenerator < Base
        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def generate(source_map)
          rspec_walker.on_each_context_block do |_namespace_name, location_range|
            add_run_lens(source_map.filename, location_range.start.line)
          end

          rspec_walker.on_example_block do |location_range|
            add_run_lens(source_map.filename, location_range.start.line)
          end
        end

        private

        # @param filename [String]
        # @param line [Integer] 0-indexed
        # @return [void]
        def add_run_lens(filename, line)
          add_code_lens(
            Solargraph::CodeLens.new(
              range: Solargraph::Range.from_to(line, 0, line, 0),
              command: Solargraph::Command.new(
                title: '▶ Run RSpec',
                command: 'solargraph.runRspec',
                arguments: [{ command: build_rspec_command(filename, line) }]
              )
            )
          )
        end
      end
    end
  end
end
