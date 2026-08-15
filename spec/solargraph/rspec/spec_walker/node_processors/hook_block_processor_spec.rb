# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::SpecWalker::NodeProcessors::HookBlockProcessor do
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

  it 'fires on_hook_block for before blocks' do
    called = 0
    code = <<~RUBY
      RSpec.describe SomeClass do
        before { do_something }
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_hook_block { called += 1 }
    end
    expect(called).to eq(1)
  end

  it 'fires on_hook_block for after blocks' do
    called = 0
    code = <<~RUBY
      RSpec.describe SomeClass do
        after { do_something }
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_hook_block { called += 1 }
    end
    expect(called).to eq(1)
  end

  it 'fires on_hook_block for around blocks' do
    called = 0
    code = <<~RUBY
      RSpec.describe SomeClass do
        around { |ex| ex.run }
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_hook_block { called += 1 }
    end
    expect(called).to eq(1)
  end

  it 'fires on_blocks_in_examples for blocks inside hook blocks' do
    called = 0
    code = <<~RUBY
      RSpec.describe SomeClass do
        before do
          do_something { subject }
        end
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_blocks_in_examples { called += 1 }
    end
    expect(called).to eq(1)
  end

  it 'does not fire on_hook_block for non-hook blocks' do
    called = 0
    code = <<~RUBY
      RSpec.describe SomeClass do
        it 'does something' do
        end
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_hook_block { called += 1 }
    end
    expect(called).to eq(0)
  end

  it 'correctly decrements depth after hook block ends' do
    called = 0
    code = <<~RUBY
      RSpec.describe SomeClass do
        before { do_something }
        let(:foo) { 1 }
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_blocks_in_examples { called += 1 }
    end
    # let block is outside hook, should not be counted
    expect(called).to eq(0)
  end
end
