# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::Generators::CodeLensGenerator do
  include SolargraphHelpers

  let(:api_map) { Solargraph::ApiMap.new }
  let(:filename) { File.expand_path('spec/models/some_namespace/transaction_spec.rb') }

  before do
    allow(Solargraph::Rspec::Gems).to receive(:gem_names).and_return(%w[rspec])
  end

  def code_lenses
    api_map.source_map(filename).convention_code_lenses
  end

  it 'generates one code lens per describe/context block' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        describe 'describing something' do
          context 'when some context' do
          end
        end
      end
    RUBY

    expect(code_lenses.size).to eq(3)
  end

  it 'generates one code lens per example block' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction do
        it 'does something' do
        end
        specify 'another thing' do
        end
      end
    RUBY

    example_lenses = code_lenses.select { |l| [1, 3].include?(l.range.start.line) }
    expect(example_lenses.size).to eq(2)
    expect(example_lenses[0].command.arguments.first[:command]).to eq("rspec #{filename}:2")
    expect(example_lenses[1].command.arguments.first[:command]).to eq("rspec #{filename}:4")
  end

  it 'sets lens range to the block start line (0-indexed)' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction do
        describe 'nested' do
        end
      end
    RUBY

    expect(code_lenses[0].range.start.line).to eq(0)
    expect(code_lenses[1].range.start.line).to eq(1)
  end

  it 'uses solargraph.runRspec as the lens command' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction do
      end
    RUBY

    expect(code_lenses.first.command.command).to eq('solargraph.runRspec')
    expect(code_lenses.first.command.title).to eq('▶ Run RSpec')
  end

  it 'builds the rspec command with the correct file and 1-indexed line number' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction do
        context 'nested' do
        end
      end
    RUBY

    expect(code_lenses[0].command.arguments.first[:command]).to eq("rspec #{filename}:1")
    expect(code_lenses[1].command.arguments.first[:command]).to eq("rspec #{filename}:2")
  end

  describe 'with bundler configured' do
    before do
      allow_any_instance_of(Solargraph::Rspec::Config).to receive(:use_bundler).and_return(true)
      allow_any_instance_of(Solargraph::Rspec::Config).to receive(:bundler_path).and_return('bundle')
    end

    it 'prefixes the command with bundle exec' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction do
        end
      RUBY

      expect(code_lenses.first.command.arguments.first[:command]).to eq("bundle exec rspec #{filename}:1")
    end

    context 'with a custom bundler path' do
      before do
        allow_any_instance_of(Solargraph::Rspec::Config).to receive(:bundler_path).and_return('bin/bundle')
      end

      it 'uses the custom bundler path' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction do
          end
        RUBY

        expect(code_lenses.first.command.arguments.first[:command]).to eq("bin/bundle exec rspec #{filename}:1")
      end
    end
  end
end
