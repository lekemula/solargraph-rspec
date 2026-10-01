# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::Generators::CodeLensGenerator do
  include SolargraphHelpers

  let(:api_map) { Solargraph::ApiMap.new }
  let(:filename) { File.expand_path('spec/models/some_namespace/transaction_spec.rb') }

  before do
    skip 'solargraph does not support code lenses' unless Solargraph::Rspec::Convention.code_lenses_supported?
    allow(Solargraph::Rspec::Gems).to receive(:gem_names).and_return(%w[rspec])
  end

  def code_lenses
    api_map.source_map(filename).convention_code_lenses
  end

  def lens_commands
    code_lenses.map { |lens| [lens.range.start.line, lens.command.arguments.first[:command]] }
  end

  it 'generates a lens running the whole file on the first line' do
    load_string filename, <<~RUBY
      require 'spec_helper'

      RSpec.describe SomeNamespace::Transaction do
      end
    RUBY

    expect(lens_commands.first).to eq([0, "rspec #{filename}"])
    expect(code_lenses.first.command.title).to eq('▶ Run RSpec file')
  end

  it 'generates one code lens per describe/context block' do
    load_string filename, <<~RUBY
      require 'spec_helper'

      RSpec.describe SomeNamespace::Transaction, type: :model do
        describe 'describing something' do
          context 'when some context' do
          end
        end
      end
    RUBY

    expect(lens_commands).to eq([
                                  [0, "rspec #{filename}"],
                                  [2, "rspec #{filename}:3"],
                                  [3, "rspec #{filename}:4"],
                                  [4, "rspec #{filename}:5"]
                                ])
  end

  it 'does not duplicate the file lens for a block on the first line' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction do
        describe 'nested' do
        end
      end
    RUBY

    expect(lens_commands).to eq([[0, "rspec #{filename}"], [1, "rspec #{filename}:2"]])
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

    expect(lens_commands).to include([1, "rspec #{filename}:2"], [3, "rspec #{filename}:4"])
  end

  it 'uses solargraph.runRspec as the lens command' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction do
        it 'works' do
        end
      end
    RUBY

    expect(code_lenses.map { |lens| lens.command.command }.uniq).to eq(['solargraph.runRspec'])
    expect(code_lenses.last.command.title).to eq('▶ Run RSpec')
  end

  context 'with a path that needs shell escaping' do
    let(:filename) { File.expand_path('spec/models/some namespace/transaction_spec.rb') }

    it 'escapes the path' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction do
          it 'works' do
          end
        end
      RUBY

      expect(lens_commands.last).to eq([1, "rspec #{Shellwords.escape("#{filename}:2")}"])
    end

    it 'keeps the unescaped target for clients that spawn rspec themselves' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction do
          it 'works' do
          end
        end
      RUBY

      expect(code_lenses.last.command.arguments.first).to include(executable: ['rspec'], target: "#{filename}:2")
    end
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

      expect(lens_commands).to eq([[0, "bundle exec rspec #{filename}"]])
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

        expect(lens_commands).to eq([[0, "bin/bundle exec rspec #{filename}"]])
        expect(code_lenses.first.command.arguments.first[:executable]).to eq(%w[bin/bundle exec rspec])
      end
    end
  end
end
