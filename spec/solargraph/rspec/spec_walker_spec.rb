# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::SpecWalker do
  let(:api_map) { Solargraph::ApiMap.new }
  let(:filename) { File.expand_path('spec/models/some_namespace/transaction_spec.rb') }
  let(:config) { Solargraph::Rspec::Config.new }
  let(:source_map) { api_map.source_maps.first }

  # @param code [String]
  # @yieldparam [Solargraph::Rspec::SpecWalker]
  # @return [void]
  def walk_code(code)
    load_string filename, code
    walker = Solargraph::Rspec::SpecWalker.new(source_map: source_map, config: config)

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
      # @param walker [Solargraph::Rspec::SpecWalker]
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
      # @param walker [Solargraph::Rspec::SpecWalker]
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
      # @param walker [Solargraph::Rspec::SpecWalker]
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
        RSpec.describe SomeClass, type: :model do
          subject(:test) { SomeClass.new }

          context 'when something' do
            subject { test }
          end
        end
      RUBY

      called = 0
      # @param walker [Solargraph::Rspec::SpecWalker]
      walk_code(code) do |walker|
        walker.on_subject do |_|
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
      # @param walker [Solargraph::Rspec::SpecWalker]
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
      # @param walker [Solargraph::Rspec::SpecWalker]
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
