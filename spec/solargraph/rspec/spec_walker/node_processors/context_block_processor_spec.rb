# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::SpecWalker::NodeProcessors::ContextBlockProcessor do
  let(:api_map) { Solargraph::ApiMap.new }
  let(:filename) { File.expand_path('spec/models/some_namespace/transaction_spec.rb') }
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

  it 'fires on_each_context_block for describe blocks' do
    namespaces = []
    walk_code('RSpec.describe SomeClass do end') do |walker|
      walker.on_each_context_block { |ns, _| namespaces << ns }
    end
    expect(namespaces).to eq(['RSpec::ExampleGroups::TestSomeClass'])
  end

  it 'fires on_described_class for constant description' do
    class_names = []
    walk_code('RSpec.describe SomeClass do end') do |walker|
      walker.on_described_class { |name, _| class_names << name }
    end
    expect(class_names).to eq(['SomeClass'])
  end

  it 'does not fire on_described_class for string description' do
    class_names = []
    walk_code('RSpec.describe "something" do end') do |walker|
      walker.on_described_class { |name, _| class_names << name }
    end
    expect(class_names).to be_empty
  end

  it 'does not fire on_each_context_block for non-context blocks' do
    namespaces = []
    walk_code('RSpec.describe SomeClass do; let(:foo) { }; end') do |walker|
      walker.on_each_context_block { |ns, _| namespaces << ns }
    end
    # Only the describe block itself, not the let block
    expect(namespaces).to eq(['RSpec::ExampleGroups::TestSomeClass'])
  end

  it 'correctly nests namespace for nested context blocks' do
    namespaces = []
    code = <<~RUBY
      RSpec.describe SomeClass do
        context 'when something' do
        end
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_each_context_block { |ns, _| namespaces << ns }
    end
    expect(namespaces).to eq([
      'RSpec::ExampleGroups::TestSomeClass',
      'RSpec::ExampleGroups::TestSomeClass::WhenSomething'
    ])
  end

  it 'correctly restores namespace_stack after nested contexts' do
    outer_ns = nil
    code = <<~RUBY
      RSpec.describe SomeClass do
        context 'inner' do
        end
      end
    RUBY
    walk_code(code) do |walker|
      walker.after_walk { outer_ns = walker.namespace_stack.last }
    end
    expect(outer_ns).to eq(Solargraph::Rspec::ROOT_NAMESPACE)
  end
end
