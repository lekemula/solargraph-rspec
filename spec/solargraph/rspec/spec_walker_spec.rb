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
    walker = described_class.new(source_map: source_map, config: config)

    yield walker

    walker.walk!
  end

  describe '#on_described_class' do
    it 'yields each context block' do
      code = <<~RUBY
        RSpec.describe SomeNamespace::SomeClass, type: :model do
        end
      RUBY

      called = 0
      # @param walker [Solargraph::Rspec::SpecWalker]
      walk_code(code) do |walker|
        walker.on_described_class do |class_name, location_range|
          called += 1
          expect(class_name).to eq('SomeNamespace::SomeClass')
          expect(location_range).to eq(Solargraph::Range.from_to(0, 15, 0, 39))
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

      let_names = []
      # @param walker [Solargraph::Rspec::SpecWalker]
      walk_code(code) do |walker|
        walker.on_let_method do |method_name, location_range|
          let_names << method_name
          expect(location_range).to be_a(Solargraph::Range)
        end
      end

      expect(let_names).to eq(%w[test test_2])
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

      subject_names = []
      # @param walker [Solargraph::Rspec::SpecWalker]
      walk_code(code) do |walker|
        walker.on_subject do |subject_name, location_range|
          subject_names << subject_name
          expect(location_range).to be_a(Solargraph::Range)
        end
      end

      expect(subject_names).to eq(['test', nil])
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

      namespaces = []
      # @param walker [Solargraph::Rspec::SpecWalker]
      walk_code(code) do |walker|
        walker.on_each_context_block do |namespace_name, location_range|
          namespaces << namespace_name
          expect(location_range).to be_a(Solargraph::Range)
        end
      end

      expect(namespaces).to eq(['RSpec::ExampleGroups::SomeNamespaceSomeClass',
                                'RSpec::ExampleGroups::SomeNamespaceSomeClass::WhenSomething'])
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
        walker.on_example_block do |location_range|
          called += 1
          expect(location_range).to be_a(Solargraph::Range)
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
        walker.on_hook_block do |location_range|
          called += 1
          expect(location_range).to be_a(Solargraph::Range)
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
        walker.on_blocks_in_examples do |location_range|
          called += 1
          expect(location_range).to be_a(Solargraph::Range)
        end
      end

      expect(called).to eq(4)
    end
  end
end
