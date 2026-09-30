# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::RSpecConfigure do
  let(:api_map) { Solargraph::ApiMap.new }
  let(:helper_file_path) { 'spec/spec_helper.rb' }
  let(:spec_file_path) { File.expand_path('spec/models/transaction_spec.rb') }

  before do
    # For performance reasons, avoid solargraph loading all installed gems' YARDoc and RBS gem pins.
    allow(Solargraph::Rspec::Gems).to receive(:gem_names).and_return(%w[rspec])

    # Mock Dir.glob to return no support files for simplicity
    allow(Dir).to receive(:[]).and_call_original
    allow(Dir).to receive(:[]).with('spec/support/**/*.rb').and_return([])
  end

  describe 'included modules from RSpec.configure' do
    let(:helper_content) do
      <<~RUBY
        module CustomHelpers
          def custom_helper_method
            "helper"
          end
        end

        RSpec.configure do |config|
          config.include CustomHelpers
        end
      RUBY
    end

    before do
      # Mock File.read for helper file
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(helper_file_path).and_return(helper_content)
    end

    it 'includes methods from modules in RSpec.configure in example blocks' do
      # Create a source for the helper file with the module definition
      helper_source = parse_string helper_file_path, helper_content

      spec_source = parse_string spec_file_path, <<~RUBY
        RSpec.describe Transaction do
          it 'should have access to custom helpers' do
            custom_helper_
          end
        end
      RUBY

      load_sources(helper_source, spec_source)

      expect(completion_at(spec_file_path, [2, 19])).to include('custom_helper_method')
    end

    it 'includes methods from modules in RSpec.configure in let blocks' do
      helper_source = parse_string helper_file_path, helper_content

      spec_source = parse_string spec_file_path, <<~RUBY
        RSpec.describe Transaction do
          let(:value) { custom_helper_ }
        end
      RUBY

      load_sources(helper_source, spec_source)

      expect(completion_at(spec_file_path, [1, 28])).to include('custom_helper_method')
    end

    it 'includes methods from modules in RSpec.configure in hook blocks' do
      helper_source = parse_string helper_file_path, helper_content

      spec_source = parse_string spec_file_path, <<~RUBY
        RSpec.describe Transaction do
          before do
            custom_helper_
          end
        end
      RUBY

      load_sources(helper_source, spec_source)

      expect(completion_at(spec_file_path, [2, 19])).to include('custom_helper_method')
    end

    it 'includes methods from modules in RSpec.configure in nested context blocks' do
      helper_source = parse_string helper_file_path, helper_content

      spec_source = parse_string spec_file_path, <<~RUBY
        RSpec.describe Transaction do
          context 'nested context' do
            it 'should have access' do
              custom_helper_
            end
          end
        end
      RUBY

      load_sources(helper_source, spec_source)

      expect(completion_at(spec_file_path, [3, 21])).to include('custom_helper_method')
    end

    context 'when helper file does not exist' do
      it 'does not raise an error' do
        # Don't create a helper source - RSpecConfigure should handle missing files gracefully
        spec_source = parse_string spec_file_path, <<~RUBY
          RSpec.describe Transaction do
            it 'test' do
            end
          end
        RUBY

        expect do
          load_sources(spec_source)
        end.not_to raise_error
      end
    end

    context 'with multiple included modules' do
      let(:multi_helper_content) do
        <<~RUBY
          module FirstModule
            def first_method
            end
          end

          module SecondModule
            def second_method
            end
          end

          RSpec.configure do |config|
            config.include FirstModule
            config.include SecondModule
          end
        RUBY
      end

      before do
        allow(File).to receive(:read).with(helper_file_path).and_return(multi_helper_content)
      end

      it 'includes methods from all configured modules' do
        helper_source = parse_string helper_file_path, multi_helper_content

        spec_source = parse_string spec_file_path, <<~RUBY
          RSpec.describe Transaction do
            it 'has all methods' do
              first_
              second_
            end
          end
        RUBY

        load_sources(helper_source, spec_source)

        expect(completion_at(spec_file_path, [2, 11])).to include('first_method')
        expect(completion_at(spec_file_path, [3, 12])).to include('second_method')
      end
    end
  end
end
