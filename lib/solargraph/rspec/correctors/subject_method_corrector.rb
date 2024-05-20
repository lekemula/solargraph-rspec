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
          rspec_walker.on_subject do |subject_name, location_range, fake_method_ast|
            next unless subject_name

            namespace_pin = closest_namespace_pin(namespace_pins, location_range.start.line)
            next unless namespace_pin

            subject_pin = rspec_let_method(namespace_pin, subject_name, location_range, fake_method_ast)
            yield [subject_pin].compact if block_given?
          end
        end
      end
    end
  end
end
