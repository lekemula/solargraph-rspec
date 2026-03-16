# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::SpecWalker::NodeProcessors::ExampleBlockProcessor do
  let(:api_map) { Solargraph::ApiMap.new }
  let(:filename) { File.expand_path('spec/models/transaction_spec.rb') }
  let(:config) { Solargraph::Rspec::Config.new }
  let(:source_map) { api_map.source_maps.first }

  before do
    allow(Solargraph::Rspec::Gems).to receive(:gem_names).and_return([])
  end

  def walk_code(code)
    load_string filename, code
    walker = Solargraph::Rspec::SpecWalker.new(source_map: source_map, config: config)
    yield walker
    walker.walk!
  end

  it 'fires on_example_block for it blocks' do
    called = 0
    code = <<~RUBY
      RSpec.describe SomeClass do
        it 'does something' do
        end
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_example_block { called += 1 }
    end
    expect(called).to eq(1)
  end

  it 'fires on_blocks_in_examples for blocks inside example blocks' do
    called = 0
    code = <<~RUBY
      RSpec.describe SomeClass do
        it 'does something' do
          expect { subject }.to change { SomeClass.count }
        end
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_blocks_in_examples { called += 1 }
    end
    expect(called).to eq(2)
  end

  it 'does not fire on_example_block for context blocks' do
    called = 0
    code = <<~RUBY
      RSpec.describe SomeClass do
        context 'when something' do
        end
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_example_block { called += 1 }
    end
    expect(called).to eq(0)
  end

  it 'correctly decrements depth after example block ends' do
    # Blocks outside the example should not trigger on_blocks_in_examples
    called = 0
    code = <<~RUBY
      RSpec.describe SomeClass do
        it 'does something' do
        end
        let(:foo) { 1 }
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_blocks_in_examples { called += 1 }
    end
    # let block is outside example, should not be counted
    expect(called).to eq(0)
  end
end
