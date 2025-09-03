# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::Convention do
  let(:api_map) { Solargraph::ApiMap.new }
  let(:library) { Solargraph::Library.new }
  let(:filename) { File.expand_path('spec/models/shared_examples_spec.rb') }

  describe 'shared examples support' do
    it 'provides completion for shared example names in include_examples' do
      load_string filename, <<~RUBY
        RSpec.shared_examples 'a shared example' do
          it 'does something' do
            expect(true).to eq(true)
          end
        end

        RSpec.shared_examples 'another shared example' do
          it 'does something else' do
            expect(false).to eq(false)
          end
        end

        RSpec.describe SomeClass do
          include_examples 'a shared example'
        end
      RUBY

      # Check that factory parameters are created for shared examples
      factory_params = api_map.pins.select { |pin| pin.is_a?(Solargraph::Pin::FactoryParameter) }

      shared_example_params = factory_params.select do |pin|
        pin.method_name == 'include_examples' &&
          pin.method_namespace == 'RSpec::Core::ExampleGroup' &&
          pin.method_scope == :class
      end

      expect(shared_example_params.map(&:value)).to include('a shared example', 'another shared example')
    end

    it 'provides completion for shared example names in it_behaves_like' do
      load_string filename, <<~RUBY
        RSpec.shared_examples 'behaves like something' do
          it 'has behavior' do
            expect(subject).to be_truthy
          end
        end

        RSpec.describe SomeClass do
          it_behaves_like 'behaves like something'
        end
      RUBY

      factory_params = api_map.pins.select { |pin| pin.is_a?(Solargraph::Pin::FactoryParameter) }

      behaves_like_params = factory_params.select do |pin|
        pin.method_name == 'it_behaves_like' &&
          pin.method_namespace == 'RSpec::Core::ExampleGroup' &&
          pin.method_scope == :class
      end

      expect(behaves_like_params.map(&:value)).to include('behaves like something')
    end

    it 'provides completion for shared example names in it_should_behave_like' do
      load_string filename, <<~RUBY
        RSpec.shared_examples 'legacy behavior' do
          it 'works with old syntax' do
            expect(1).to eq(1)
          end
        end

        RSpec.describe SomeClass do
          it_should_behave_like 'legacy behavior'
        end
      RUBY

      factory_params = api_map.pins.select { |pin| pin.is_a?(Solargraph::Pin::FactoryParameter) }

      should_behave_params = factory_params.select do |pin|
        pin.method_name == 'it_should_behave_like' &&
          pin.method_namespace == 'RSpec::Core::ExampleGroup' &&
          pin.method_scope == :class
      end

      expect(should_behave_params.map(&:value)).to include('legacy behavior')
    end

    it 'supports shared_context and include_context' do
      load_string filename, <<~RUBY
        RSpec.shared_context 'with setup' do
          let(:value) { 42 }
        end

        RSpec.describe SomeClass do
          include_context 'with setup'
        end
      RUBY

      factory_params = api_map.pins.select { |pin| pin.is_a?(Solargraph::Pin::FactoryParameter) }

      context_params = factory_params.select do |pin|
        pin.method_name == 'include_context' &&
          pin.method_namespace == 'RSpec::Core::ExampleGroup' &&
          pin.method_scope == :class
      end

      expect(context_params.map(&:value)).to include('with setup')
    end

    it 'handles shared examples with symbols' do
      load_string filename, <<~RUBY
        RSpec.shared_examples :symbol_example do
          it 'works with symbols' do
            expect(true).to be true
          end
        end

        RSpec.describe SomeClass do
          include_examples :symbol_example
        end
      RUBY

      factory_params = api_map.pins.select { |pin| pin.is_a?(Solargraph::Pin::FactoryParameter) }

      symbol_params = factory_params.select do |pin|
        pin.method_name == 'include_examples' &&
          pin.method_namespace == 'RSpec::Core::ExampleGroup' &&
          pin.method_scope == :class
      end

      expect(symbol_params.map(&:value)).to include(:symbol_example)
    end

    it 'works with shared_examples_for alias' do
      load_string filename, <<~RUBY
        RSpec.shared_examples_for 'aliased example' do
          it 'uses the alias' do
            expect(42).to eq(42)
          end
        end

        RSpec.describe SomeClass do
          include_examples 'aliased example'
        end
      RUBY

      factory_params = api_map.pins.select { |pin| pin.is_a?(Solargraph::Pin::FactoryParameter) }

      alias_params = factory_params.select do |pin|
        pin.method_name == 'include_examples' &&
          pin.method_namespace == 'RSpec::Core::ExampleGroup' &&
          pin.method_scope == :class
      end

      expect(alias_params.map(&:value)).to include('aliased example')
    end
  end
end
