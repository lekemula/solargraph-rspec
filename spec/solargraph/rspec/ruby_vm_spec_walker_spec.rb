# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::RubyVMSpecWalker do
  let(:api_map) { Solargraph::ApiMap.new }
  let(:filename) { File.expand_path('spec/models/some_namespace/transaction_spec.rb') }
  let(:config) { Solargraph::Rspec::Config.new }
  let(:source_map) { api_map.source_maps.first }

  describe Solargraph::Rspec::RubyVMSpecWalker::NodeTypes do
    def parse(code)
      RubyVM::AbstractSyntaxTree.parse(code)
    end

    describe '.a_block?' do
      it 'returns true for block nodes' do
        node = parse('describe "something" do end')
        expect(described_class.a_block?(node.children[2])).to be(true)
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
    end

    describe '.a_context_block?' do
      it 'returns true for subject block with name' do
        node = parse('subject(:something) { }')
        expect(described_class.a_subject_block?(node.children[2])).to be(true)
      end

      it 'returns true for subject block without name' do
        node = parse('subject { }')

        expect(described_class.a_subject_block?(node.children[2])).to be(true)
      end
    end

    describe '.a_example_block?' do
      it 'returns true for example block with name' do
        node = parse('it("does something") { }')
        expect(described_class.a_example_block?(node.children[2])).to be(true)
      end

      it 'returns true for example block without name' do
        node = parse('it { }')

        expect(described_class.a_example_block?(node.children[2])).to be(true)
      end
    end

    describe '.a_hook_block?' do
      it 'returns true for example block with name' do
        node = parse('before { }')
        expect(described_class.a_hook_block?(node.children[2])).to be(true)
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

  # @param code [String]
  # @yieldparam [Solargraph::Rspec::RubyVMSpecWalker]
  # @return [void]
  def walk_code(code)
    load_string filename, code
    walker = Solargraph::Rspec::RubyVMSpecWalker.new(source_map: source_map, config: config)

    yield walker

    walker.walk!
  end

  describe '#on_described_class' do
    it 'yields each context block' do
      code = <<~RUBY
        RSpec.describe SomeClass, type: :model do
        end
      RUBY

      called = 0
      # @param walker [Solargraph::Rspec::RubyVMSpecWalker]
      walk_code(code) do |walker|
        walker.on_described_class do |_|
          called += 1
        end
      end

      expect(called).to eq(1)
    end
  end

  describe '#on_let_method' do
    it 'yields each context block' do
      code = <<~RUBY
        RSpec.describe SomeClass, type: :model do
          let(:test) { SomeClass.new }

          context 'when something' do
            let(:test_2) { SomeClass.new }
          end
        end
      RUBY

      called = 0
      # @param walker [Solargraph::Rspec::RubyVMSpecWalker]
      walk_code(code) do |walker|
        walker.on_let_method do |_|
          called += 1
        end
      end

      expect(called).to eq(2)
    end
  end

  describe '#on_subject' do
    it 'yields each context block' do
      code = <<~RUBY
        RSpec.describe SomeClass, type: :model do
          subject(:test) { SomeClass.new }

          context 'when something' do
            subject { test }
          end
        end
      RUBY

      called = 0
      # @param walker [Solargraph::Rspec::RubyVMSpecWalker]
      walk_code(code) do |walker|
        walker.on_subject do |_|
          called += 1
        end
      end

      expect(called).to eq(2)
    end
  end

  describe '#on_each_context_block' do
    it 'yields each context block' do
      code = <<~RUBY
        RSpec.describe SomeNamespace::SomeClass, type: :model do
          non_context_block do
          end

          context 'when something' do
            other_non_context_block { }
          end
        end
      RUBY

      called = 0
      # @param walker [Solargraph::Rspec::RubyVMSpecWalker]
      walk_code(code) do |walker|
        walker.on_each_context_block do |_|
          called += 1
        end
      end

      expect(called).to eq(2)
    end
  end

  describe '#on_example_block' do
    it 'yields each context block' do
      code = <<~RUBY
        RSpec.describe SomeClass, type: :model do
          it 'does something' do
          end

          context 'when something' do
            it 'does something' do
            end
          end
        end
      RUBY

      called = 0
      # @param walker [Solargraph::Rspec::RubyVMSpecWalker]
      walk_code(code) do |walker|
        walker.on_example_block do |_|
          called += 1
        end
      end

      expect(called).to eq(2)
    end
  end

  describe '#on_hook_block' do
    it 'yields each context block' do
      code = <<~RUBY
        RSpec.describe SomeClass, type: :model do
          before do
          end

          context 'when something' do
            after do
            end

            around do
            end
          end
        end
      RUBY

      called = 0
      # @param walker [Solargraph::Rspec::RubyVMSpecWalker]
      walk_code(code) do |walker|
        walker.on_hook_block do |_|
          called += 1
        end
      end

      expect(called).to eq(3)
    end
  end

  describe '#on_blocks_in_examples' do
    it 'yields each context block' do
      code = <<~RUBY
        RSpec.describe SomeClass, type: :model do
          it 'does something' do
            expect { subject }.to change { SomeClass.count }.by(1)
          end

          context 'when something' do
            around do
              do_something { subject }
            end

            it 'does something' do
              do_something_too { subject }
            end
          end
        end
      RUBY

      called = 0
      # @param walker [Solargraph::Rspec::SpecWalker]
      walk_code(code) do |walker|
        walker.on_blocks_in_examples do |_|
          called += 1
        end
      end

      expect(called).to eq(4)
    end
  end
end
