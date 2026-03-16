# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::SpecWalker::NodeProcessors::LetMethodProcessor do
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

  it 'fires on_let_method for let blocks with a symbol name' do
    let_names = []
    code = <<~RUBY
      RSpec.describe SomeClass do
        let(:foo) { 1 }
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_let_method { |name, _, _| let_names << name }
    end
    expect(let_names).to eq(['foo'])
  end

  it 'does not fire on_let_method for let blocks without a symbol name' do
    let_names = []
    code = <<~RUBY
      RSpec.describe SomeClass do
        let { 1 }
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_let_method { |name, _, _| let_names << name }
    end
    expect(let_names).to be_empty
  end

  it 'does not fire on_let_method for non-let blocks' do
    let_names = []
    code = <<~RUBY
      RSpec.describe SomeClass do
        subject(:foo) { 1 }
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_let_method { |name, _, _| let_names << name }
    end
    expect(let_names).to be_empty
  end

  it 'provides a fake method AST via on_let_method' do
    method_asts = []
    code = <<~RUBY
      RSpec.describe SomeClass do
        let(:bar) { 42 }
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_let_method { |_, _, ast| method_asts << ast }
    end
    expect(method_asts.first).to be_a(::Parser::AST::Node)
    expect(method_asts.first.type).to eq(:def)
    expect(method_asts.first.children.first).to eq(:bar)
  end
end
