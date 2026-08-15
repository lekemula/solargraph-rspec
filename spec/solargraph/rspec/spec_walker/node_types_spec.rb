# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::SpecWalker::NodeTypes do
  def parse(code)
    described_class.to_rubocop_ast(Solargraph::Parser.parse(code))
  end

  describe '.to_rubocop_ast' do
    it 'converts a Parser::AST::Node to RuboCop::AST::Node' do
      node = Solargraph::Parser.parse('foo { }')
      result = described_class.to_rubocop_ast(node)
      expect(result).to be_a(RuboCop::AST::Node)
    end

    it 'returns the node unchanged if already a RuboCop::AST::Node' do
      node = parse('foo { }')
      expect(described_class.to_rubocop_ast(node)).to equal(node)
    end

    it 'returns non-node values unchanged' do
      expect(described_class.to_rubocop_ast(:symbol)).to eq(:symbol)
    end
  end

  describe '.block_method_name' do
    it 'returns the method name symbol for a block node' do
      node = parse('it("something") { }')
      expect(described_class.block_method_name(node)).to eq(:it)
    end

    it 'returns nil for a non-block node' do
      node = parse('foo')
      expect(described_class.block_method_name(node)).to be_nil
    end
  end

  describe '.context_description_node' do
    it 'returns the description node for a context block' do
      node = parse('describe "something" do end')
      desc = described_class.context_description_node(node)
      expect(desc.children.first).to eq('something')
    end

    it 'returns the constant node for a constant description' do
      node = parse(<<~RUBY)
        RSpec.describe SomeNamespace::SomeClass, type: :model do
        end
      RUBY
      desc = described_class.context_description_node(node)
      expect(desc.children.last).to eq(:SomeClass)
    end

    it 'returns nil for a non-block node' do
      node = parse('foo')
      expect(described_class.context_description_node(node)).to be_nil
    end
  end

  describe '.let_symbol_name' do
    it 'returns the symbol name for a let block' do
      node = parse('let(:something) { }')
      expect(described_class.let_symbol_name(node)).to eq(:something)
    end

    it 'returns nil for a let block without a symbol name' do
      node = parse('let { }')
      expect(described_class.let_symbol_name(node)).to be_nil
    end

    it 'returns nil for a non-block node' do
      node = parse('foo')
      expect(described_class.let_symbol_name(node)).to be_nil
    end
  end

  describe '.let_block_method?' do
    let(:config) { Solargraph::Rspec::Config.new }

    it 'returns true for a configured let method name' do
      expect(described_class.let_block_method?(:let, config)).to be(true)
    end

    it 'returns true when given a string' do
      expect(described_class.let_block_method?('let!', config)).to be(true)
    end

    it 'returns false for an unknown method name' do
      expect(described_class.let_block_method?(:foo, config)).to be(false)
    end
  end

  describe '.example_block_method?' do
    let(:config) { Solargraph::Rspec::Config.new }

    it 'returns true for a configured example method name' do
      expect(described_class.example_block_method?(:it, config)).to be(true)
    end

    it 'returns true when given a string' do
      expect(described_class.example_block_method?('specify', config)).to be(true)
    end

    it 'returns false for an unknown method name' do
      expect(described_class.example_block_method?(:foo, config)).to be(false)
    end
  end

  describe '.a_example_block?' do
    let(:config) { Solargraph::Rspec::Config.new }

    it 'returns true for an example block with a name' do
      node = parse('it("does something") { }')
      expect(described_class.a_example_block?(node, config)).to be(true)
    end

    it 'returns true for an example block without a name' do
      node = parse('it { }')
      expect(described_class.a_example_block?(node, config)).to be(true)
    end

    it 'returns false for a non-example block' do
      node = parse('non_example { }')
      expect(described_class.a_example_block?(node, config)).to be(false)
    end
  end

  describe '.a_constant?' do
    it 'returns true for a constant node' do
      node = parse('SomeClass')
      expect(described_class.a_constant?(node)).to be(true)
    end

    it 'returns false for a non-constant node' do
      node = parse('foo')
      expect(described_class.a_constant?(node)).to be(false)
    end

    it 'returns false for non-node values' do
      expect(described_class.a_constant?('string')).to be(false)
    end
  end
end
