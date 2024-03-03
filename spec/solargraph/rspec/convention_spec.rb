# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::Convention do
  let(:api_map) { Solargraph::ApiMap.new }
  let(:library) { Solargraph::Library.new }

  it 'generates method for described_class' do
    filename = File.expand_path('spec/models/some_namespace/transaction_spec.rb')
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        context 'some context' do
          it 'should do something' do
            descr
          end
        end
      end
    RUBY

    assert_public_instance_method(api_map, 'RSpec::ExampleGroups::SomeNamespaceTransaction#described_class',
                                  ['Class<SomeNamespace::Transaction>']) do |pin|
      expect(pin.location.filename).to eq(filename)
      expect(pin.location.range.to_hash).to eq(
        { start: { line: 0, character: 0 }, end: { line: 0, character: 15 } }
      )
    end

    expect(completion_at(filename, [3, 11])).to include('described_class')
  end

  it 'generates method for lets/subject definitions' do
    filename = File.expand_path('spec/models/some_namespace/transaction_spec.rb')
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        subject(:transaction) { described_class.new }
        let(:something) { 1 }
        let!(:something_else) { 2 }

        it 'should do something' do
          tran
          some
        end

        context 'nested context' do
          let(:nested_something) { 1 }

          it 'should do something' do
            tran
            some
            nest
          end

          describe 'nested nested context' do
            it 'DELETE /users/:user_id' do
              tran
              some
              nest
            end
          end
        end
      end
    RUBY

    assert_public_instance_method(api_map, 'RSpec::ExampleGroups::SomeNamespaceTransaction#transaction', ['undefined'])
    assert_public_instance_method(api_map, 'RSpec::ExampleGroups::SomeNamespaceTransaction#something', ['undefined'])
    assert_public_instance_method(api_map, 'RSpec::ExampleGroups::SomeNamespaceTransaction#something_else',
                                  ['undefined'])
    assert_public_instance_method(api_map,
                                  'RSpec::ExampleGroups::SomeNamespaceTransaction::NestedContext#nested_something', ['undefined'])
    expect(completion_at(filename, [6, 8])).to include('transaction')
    expect(completion_at(filename, [7, 8])).to include('something')
    expect(completion_at(filename, [7, 8])).to include('something_else')
    expect(completion_at(filename, [14, 8])).to include('transaction')
    expect(completion_at(filename, [15, 8])).to include('something')
    expect(completion_at(filename, [16, 8])).to include('nested_something')
    expect(completion_at(filename, [21, 8])).to include('transaction')
    expect(completion_at(filename, [22, 8])).to include('something')
    expect(completion_at(filename, [22, 8])).to include('nested_something')
  end

  it 'generates implicit subject method' do
    filename = File.expand_path('spec/models/some_namespace/transaction_spec.rb')
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        it 'should do something' do
          sub
        end
      end
    RUBY

    assert_public_instance_method(api_map, 'RSpec::ExampleGroups::SomeNamespaceTransaction#subject',
                                  ['SomeNamespace::Transaction'])
    expect(completion_at(filename, [2, 6])).to include('subject')
  end

  it 'generates modules for describe/context blocks' do
    filename = File.expand_path('spec/models/some_namespace/transaction_spec.rb')
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        describe 'describing something' do
          context 'when some context' do
            let(:something) { 1 }

            it 'should do something' do
            end
          end

          context 'TEST_some/symbols-' do
            let(:something) { 1 }

            it 'should do something' do
            end
          end
        end
      end
    RUBY

    assert_namespace(api_map, 'RSpec::ExampleGroups::SomeNamespaceTransaction')
    assert_namespace(api_map, 'RSpec::ExampleGroups::SomeNamespaceTransaction::DescribingSomething')
    assert_namespace(api_map, 'RSpec::ExampleGroups::SomeNamespaceTransaction::DescribingSomething::WhenSomeContext')
    assert_namespace(api_map, 'RSpec::ExampleGroups::SomeNamespaceTransaction::DescribingSomething::TESTSomeSymbols')
  end

  it 'shouldn\'t complete for rspec definitions from other spec files' do
    filename1 = File.expand_path('spec/models/test_one_spec.rb')
    file1 = load_string filename1, <<~RUBY
      RSpec.describe TestOne, type: :model do
        let(:variable_one) { 1 }

        it 'should do something' do
          vari
        end
      end
    RUBY

    filename2 = File.expand_path('spec/models/test_two_spec.rb')
    file2 = load_string filename2, <<~RUBY
      RSpec.describe TestTwo, type: :model do
          it 'should do something' do
            vari
          end
          context 'test', sometag: true do
          end
      end
    RUBY

    load_sources(file1, file2)

    expect(completion_at(filename1, [4, 10])).to include('variable_one')
    expect(completion_at(filename2, [2, 10])).to_not include('variable_one')
  end

  it 'completes RSpec::Matchers methods' do
    filename = File.expand_path('spec/models/some_namespace/transaction_spec.rb')
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        context 'some context' do
          it 'should do something' do
            expect(subject).to be_a_
          end
        end
      end
    RUBY

    expect(completion_at(filename, [3, 29])).to include('be_a_kind_of')
  end

  it 'completes normal ruby methods' do
    filename = File.expand_path('spec/models/some_namespace/transaction_spec.rb')
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        def my_method
        end

        context 'some context' do
          it 'should do something' do
            my_me
          end
        end
      end
      my_meth
    RUBY

    # expect(completion_at(filename, [7, 11])).to include('my_method')
    expect(completion_at(filename, [10, 5])).to include('my_method')
  end

  describe 'configurations' do
    describe 'let_methods' do
      before(:each) do
        Solargraph::Rspec::Convention.instance_variable_set(:@config, nil)
        @global_path = File.realpath(Dir.mktmpdir)
        @orig_env = ENV['SOLARGRAPH_GLOBAL_CONFIG']
        ENV['SOLARGRAPH_GLOBAL_CONFIG'] = File.join(@global_path, '.solargraph.yml')

        File.open(File.join(@global_path, '.solargraph.yml'), 'w') do |file|
          configuration.each_line do |line|
            file.puts line
          end
        end
      end

      after(:each) do
        ENV['SOLARGRAPH_GLOBAL_CONFIG'] = @orig_env
        FileUtils.remove_entry(@global_path)
      end

      let(:configuration) do
        <<~YAML
          rspec:
            let_methods:
              - let_it_be
        YAML
      end

      it 'generates method for additional let-like methods' do
        filename = File.expand_path('spec/models/some_namespace/transaction_spec.rb')
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :model do
            let_it_be(:transaction) { described_class.new }

            it 'should do something' do
              tran
            end
          end
        RUBY

        assert_public_instance_method(api_map, 'RSpec::ExampleGroups::SomeNamespaceTransaction#transaction',
                                      ['undefined'])
        expect(completion_at(filename, [4, 7])).to include('transaction')
      end
    end
  end
end
