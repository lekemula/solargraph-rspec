# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::SpecWalker::NodeProcessors::SubjectProcessor do
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

  it 'fires on_subject for named subject blocks' do
    subject_names = []
    code = <<~RUBY
      RSpec.describe SomeClass do
        subject(:my_subject) { SomeClass.new }
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_subject { |name, _, _| subject_names << name }
    end
    expect(subject_names).to eq(['my_subject'])
  end

  it 'fires on_subject with nil name for anonymous subject blocks' do
    subject_names = []
    code = <<~RUBY
      RSpec.describe SomeClass do
        subject { SomeClass.new }
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_subject { |name, _, _| subject_names << name }
    end
    expect(subject_names).to eq([nil])
  end

  it 'does not fire on_subject for let blocks' do
    subject_names = []
    code = <<~RUBY
      RSpec.describe SomeClass do
        let(:foo) { 1 }
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_subject { |name, _, _| subject_names << name }
    end
    expect(subject_names).to be_empty
  end

  it 'provides a fake method AST with method name "subject" for anonymous subjects' do
    method_asts = []
    code = <<~RUBY
      RSpec.describe SomeClass do
        subject { SomeClass.new }
      end
    RUBY
    walk_code(code) do |walker|
      walker.on_subject { |_, _, ast| method_asts << ast }
    end
    expect(method_asts.first.children.first).to eq(:subject)
  end
end
