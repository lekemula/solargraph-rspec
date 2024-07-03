# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::SpecWalker::NodeTypes do
  def parse(code)
    RubyVM::AbstractSyntaxTree.parse(code)
  end

  describe '.a_block?' do
    it 'returns true for block nodes' do
      node = parse('describe "something" do end')
      expect(described_class.a_block?(node.children[2])).to be(true)
    end

    it 'returns false for non-block nodes' do
      node = parse('describe "something"')
      expect(described_class.a_block?(node.children[2])).to be(false)
    end
  end

  describe '.a_context_block?' do
    it 'returns true for RSpec context block nodes' do
      node = parse('describe "something" do end')
      expect(described_class.a_context_block?(node.children[2])).to be(true)
    end

    it 'returns true for RSpec root context block nodes' do
      node = parse(<<~RUBY)
        RSpec.describe SomeNamespace::SomeClass, type: :model do
        end
      RUBY

      expect(described_class.a_context_block?(node.children[2])).to be(true)
    end

    it 'returns false for non-RSpec context block nodes' do
      node = parse('different_context "something" do end')
      expect(described_class.a_context_block?(node.children[2])).to be(false)
    end
  end

  describe '.a_subject_block?' do
    it 'returns true for subject block with name' do
      node = parse('subject(:something) { }')
      expect(described_class.a_subject_block?(node.children[2])).to be(true)
    end

    it 'returns true for subject block without name' do
      node = parse('subject { }')

      expect(described_class.a_subject_block?(node.children[2])).to be(true)
    end

    it 'returns false for non-subject block' do
      node = parse('non_subject { }')
      expect(described_class.a_subject_block?(node.children[2])).to be(false)
    end
  end

  describe '.a_example_block?' do
    let(:config) { Solargraph::Rspec::Config.new }

    it 'returns true for example block with name' do
      node = parse('it("does something") { }')
      expect(described_class.a_example_block?(node.children[2], config)).to be(true)
    end

    it 'returns true for example block without name' do
      node = parse('it { }')
      expect(described_class.a_example_block?(node.children[2], config)).to be(true)
    end

    it 'returns false for non-example block' do
      node = parse('non_example { }')
      expect(described_class.a_example_block?(node.children[2], config)).to be(false)
    end
  end

  describe '.a_hook_block?' do
    it 'returns true for example block with name' do
      node = parse('before { }')
      expect(described_class.a_hook_block?(node.children[2])).to be(true)
    end

    it 'returns false for non-hook block' do
      node = parse('non_hook { }')
      expect(described_class.a_hook_block?(node.children[2])).to be(false)
    end
  end

  describe '.context_description_node' do
    it 'returns correct node of context description' do
      node = parse('describe "something" do end')
      desc = described_class.context_description_node(node.children[2])
      expect(desc.children.first).to eq('something')
    end

    it 'returns correct node of context root description' do
      node = parse(<<~RUBY)
        RSpec.describe SomeNamespace::SomeClass, type: :model do
        end
      RUBY

      desc = described_class.context_description_node(node.children[2])
      expect(desc.children.last).to eq(:SomeClass)
    end

    it 'returns nil for non-context block' do
      node = parse('non_context "something" do end')
      desc = described_class.context_description_node(node.children[2])
      expect(desc).to eq(nil)
    end
  end

  describe '.let_method_name' do
    it 'returns correct method name for subject block' do
      node = parse('subject(:something) { }')
      name = described_class.let_method_name(node.children[2])
      expect(name).to eq('something')
    end

    it 'returns nil for subject block without a name' do
      node = parse('subject { }')
      name = described_class.let_method_name(node.children[2])
      expect(name).to eq(nil)
    end

    it 'returns correct method name for let block' do
      node = parse('let(:something) { }')
      name = described_class.let_method_name(node.children[2])
      expect(name).to eq('something')
    end

    it 'returns nil for let block without a name' do
      node = parse('let { }')
      name = described_class.let_method_name(node.children[2])
      expect(name).to eq(nil)
    end
  end
end
