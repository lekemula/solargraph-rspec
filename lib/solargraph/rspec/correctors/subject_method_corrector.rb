# frozen_string_literal: true

require_relative 'let_methods_corrector'

module Solargraph
  module Rspec
    module Correctors
      # Defines let-like methods in the example group block
      class SubjectMethodCorrector < LetMethodsCorrector
        # @param source_map [Solargraph::SourceMap]
        # @return [void]
        def correct(_source_map)
          rspec_walker.on_subject do |ast|
            namespace_pin = closest_namespace_pin(namespace_pins, ast.loc.line)
            next unless namespace_pin

            subject_pin = rspec_let_method(namespace_pin, ast)
            yield [subject_pin].compact if block_given?
          end
        end
      end
    end
  end
end
