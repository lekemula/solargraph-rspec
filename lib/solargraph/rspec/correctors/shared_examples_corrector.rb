# frozen_string_literal: true

require_relative 'base'

module Solargraph
  module Rspec
    module Correctors
      class SharedExamplesCorrector < Base
        # @param source_map [Solargraph::SourceMap]
        def correct(source_map)
          @shared_examples = {}

          rspec_walker.on_shared_example_definition do |shared_examples_name, location_range|
            SHARED_EXAMPLE_INCLUSION_METHODS.each do |method_name|
              pin = Solargraph::Pin::FactoryParameter.new(
                method_name: method_name,
                method_namespace: 'RSpec::Core::ExampleGroup',
                method_scope: :class,
                param_name: 'name',
                value: shared_examples_name,
                return_type: nil,
                decl: :arg,
                location: PinFactory.build_location(location_range, source_map.source.filename)
              )
              add_pin(pin)
            end
          end
        end
      end
    end
  end
end
