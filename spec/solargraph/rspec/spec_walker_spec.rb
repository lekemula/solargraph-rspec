# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::SpecWalker do
  let(:api_map) { Solargraph::ApiMap.new }
  let(:filename) { File.expand_path('spec/models/some_namespace/transaction_spec.rb') }
  let(:config) { Solargraph::Rspec::Config.new }
  let(:source_map) { api_map.source_maps.first }

  def parse_expected_let_method(code)
    Solargraph::Parser.parse(code)
  end

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
    let(:fake_let_with_block) do
      parse_expected_let_method(<<~RUBY)
        def fake_test_with_block
          create(
            :some_model,
            some_attribute: 1
          ) do |model|
            model.some_attribute = 2
            model.save!
          end
        end
      RUBY
    end

    let(:fake_let_with_curly_block) do
      parse_expected_let_method(<<~RUBY)
        def fake_test_with_curly_block
          create(
            :some_model,
            some_attribute: 1
          ) do |model|
            model.some_attribute = 2
            model.save!
          end
        end
      RUBY
    end

    it 'yields each let_block' do
      code = <<~RUBY
        RSpec.describe SomeClass, type: :model do
          let(:fake_test_with_block) do
            create(
              :some_model,
              some_attribute: 1
            ) do |model|
              model.some_attribute = 2
              model.save!
            end
          end

          context 'when something' do
            let(:fake_test_with_curly_block) {
              create(
                :some_model,
                some_attribute: 1
              ) do |model|
                model.some_attribute = 2
                model.save!
              end
            }
          end
        end
      RUBY

      let_names = []
      method_asts = []
      # @param walker [Solargraph::Rspec::SpecWalker]
      walk_code(code) do |walker|
        walker.on_let_method do |method_name, location_range, method_ast|
          let_names << method_name
          method_asts << method_ast
          expect(location_range).to be_a(Solargraph::Range)
        end
      end

      expect(let_names).to eq(%w[fake_test_with_block fake_test_with_curly_block])
      expect(method_asts).to eq(
        [
          fake_let_with_block,
          fake_let_with_curly_block
        ]
      )
    end
  end

  describe '#on_subject' do
    let(:fake_subject_with_block) do
      parse_expected_let_method(<<~RUBY)
        def subject_with_block
          create(
            :some_model,
            some_attribute: 1
          ) do |model|
            model.some_attribute = 2
            model.save!
          end
        end
      RUBY
    end

    let(:fake_subject_with_curly_block) do
      parse_expected_let_method(<<~RUBY)
        def subject_with_curly_block
          create(
            :some_model,
            some_attribute: 1
          ) do |model|
            model.some_attribute = 2
            model.save!
          end
        end
      RUBY
    end

    let(:fake_subject_without_name) do
      parse_expected_let_method(<<~RUBY)
        def subject
          create(:some_model)
        end
      RUBY
    end

    it 'yields each context block' do
      code = <<~RUBY
        RSpec.describe SomeClass, type: :model do
          subject(:subject_with_block) do
            create(
              :some_model,
              some_attribute: 1
            ) do |model|
              model.some_attribute = 2
              model.save!
            end
          end

          context 'when something' do
            subject(:subject_with_curly_block) {
              create(
                :some_model,
                some_attribute: 1
              ) do |model|
                model.some_attribute = 2
                model.save!
              end
            }

            subject { create(:some_model) } # without a name
          end
        end
      RUBY

      subject_names = []
      method_asts = []
      # @param walker [Solargraph::Rspec::SpecWalker]
      walk_code(code) do |walker|
        walker.on_subject do |subject_name, location_range, method_ast|
          subject_names << subject_name
          method_asts << method_ast
          expect(location_range).to be_a(Solargraph::Range)
        end
      end

      expect(subject_names).to eq(['subject_with_block', 'subject_with_curly_block', nil])
      expect(method_asts).to eq(
        [
          fake_subject_with_block,
          fake_subject_with_curly_block,
          fake_subject_without_name
        ]
      )
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

      expect(namespaces).to eq(['RSpec::ExampleGroups::TestSomeNamespaceSomeClass',
                                'RSpec::ExampleGroups::TestSomeNamespaceSomeClass::WhenSomething'])
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
