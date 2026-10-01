# frozen_string_literal: true

require_relative 'base'

module Solargraph
  module Rspec
    module Generators
      # Generates a "Run" code lens for the whole file and for each describe/context/example block
      class CodeLensGenerator < Base
        RUN_COMMAND = 'solargraph.runRspec'

        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def generate(source_map)
          filename = source_map.filename
          # Clients such as the VS Code test explorer look up the command to run a whole file on its first line.
          add_run_lens('▶ Run RSpec file', 0, build_rspec_command(filename))

          rspec_walker.on_each_context_block do |_namespace_name, location_range|
            line = location_range.start.line
            add_run_lens('▶ Run RSpec', line, build_rspec_command(filename, line)) unless line.zero?
          end

          rspec_walker.on_example_block do |location_range|
            line = location_range.start.line
            add_run_lens('▶ Run RSpec', line, build_rspec_command(filename, line))
          end
        end

        private

        # @param title [String]
        # @param line [Integer] 0-indexed
        # @param rspec_command [Hash{Symbol => String, Array<String>}]
        # @return [void]
        def add_run_lens(title, line, rspec_command)
          add_code_lens(
            Solargraph::CodeLens.new(
              range: Solargraph::Range.from_to(line, 0, line, 0),
              command: Solargraph::Command.new(title: title, command: RUN_COMMAND, arguments: [rspec_command])
            )
          )
        end
      end
    end
  end
end
