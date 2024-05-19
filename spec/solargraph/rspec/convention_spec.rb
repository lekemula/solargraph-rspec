# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::Convention do
  let(:api_map) { Solargraph::ApiMap.new }
  let(:library) { Solargraph::Library.new }
  let(:filename) { File.expand_path('spec/models/some_namespace/transaction_spec.rb') }

  it 'generates method for described_class' do
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
      # TODO: Why does RubyVM return lines + 1 compared to Parser gem? Does this affect GoToDefinition?
      expect(pin.location.range.to_hash).to eq(
        { start: { line: 1, character: 15 }, end: { line: 1, character: 41 } }
      )
    end

    expect(completion_at(filename, [3, 11])).to include('described_class')
  end

  it 'generates method for lets/subject definitions' do
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

    assert_public_instance_method(
      api_map,
      'RSpec::ExampleGroups::SomeNamespaceTransaction#transaction',
      ['undefined']
    ) do |pin|
      expect(pin.location.range.to_hash).to eq(
        { start: { line: 1, character: 2 }, end: { line: 1, character: 23 } }
      )
    end
    assert_public_instance_method(api_map, 'RSpec::ExampleGroups::SomeNamespaceTransaction#something', ['undefined'])
    assert_public_instance_method(api_map, 'RSpec::ExampleGroups::SomeNamespaceTransaction#something_else',
                                  ['undefined'])
    assert_public_instance_method(
      api_map,
      'RSpec::ExampleGroups::SomeNamespaceTransaction::NestedContext#nested_something',
      ['undefined']
    )
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

  # NOTE: This spec depends on RSpec's YARDoc comments, if it fails try running: yard gems
  it 'completes RSpec::Matchers methods' do
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
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        def my_method
        end

        context 'some context' do
          it 'should do something' do
            my_me
            my_othe
          end

          context 'nested context' do
            def my_method # override
            end

            def my_other_method
            end

            it 'should do something else' do
              my_me
              my_othe
            end
          end
        end
      end

      my_meth
    RUBY

    expect(completion_at(filename, [6, 11])).to include('my_method')
    expect(completion_pins_at(filename, [6, 11]).first.location.range.start.line).to eq(1)
    expect(completion_at(filename, [7, 11])).not_to include('my_method') # other child/adjacent contexts
    expect(completion_at(filename, [18, 13])).to include('my_method')
    expect(completion_pins_at(filename, [18, 13]).first.location.range.start.line).to eq(11) # nearest parent context
    expect(completion_at(filename, [19, 13])).to include('my_other_method')
    expect(completion_at(filename, [25, 5])).not_to include('my_method') # outside of the RSpec block
  end

  it 'completes normal ruby class methods' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        def self.my_class_method
        end

        my_clas

        context 'some context' do
          my_clas
        end
      end
    RUBY

    expect(completion_at(filename, [4, 9])).to include('my_class_method')
    # TODO: Complete class methods from the parent context scope. This seems to be an issue with Solargraph itself.
    # expect(completion_at(filename, [7, 11])).to include('my_class_method')
  end

  it 'completes RSpec DSL methods' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        desc
        cont
        xi
        fex
        fdes

        context 'some context' do
          desc
          cont
          xi
          fex
          fdes
        end
      end
    RUBY

    assert_class_method(api_map, 'RSpec::ExampleGroups::SomeNamespaceTransaction.it', ['undefined'])
    expect(completion_at(filename, [1, 7])).to include('describe')
    expect(completion_at(filename, [2, 7])).to include('context')
    expect(completion_at(filename, [3, 7])).to include('xit')
    expect(completion_at(filename, [4, 7])).to include('fexample')
    expect(completion_at(filename, [5, 7])).to include('fdescribe')

    # context
    expect(completion_at(filename, [8, 7])).to include('describe')
    expect(completion_at(filename, [9, 7])).to include('context')
    expect(completion_at(filename, [10, 7])).to include('xit')
    expect(completion_at(filename, [11, 7])).to include('fexample')
    expect(completion_at(filename, [12, 7])).to include('fdescribe')
  end

  it 'completes inside RSpec before/after/around hook blocks' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        let(:something) { 1 }
        subject(:transaction) { someth }

        before do
          someth
        end
      end
    RUBY

    expect(completion_at(filename, [2, 29])).to include('something')
    expect(completion_at(filename, [5, 5])).to include('something')
  end

  it 'completes inside RSpec blocks in example context' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        let(:something) { 1 }

        it 'should do something' do
          someth
          expect { someth }
        end

        before do
          some_method_with_block { someth }
        end

        context 'subject without name' do
          subject { someth }
        end
      end
    RUBY

    expect(completion_at(filename, [4, 9])).to include('something')
    expect(completion_at(filename, [5, 17])).to include('something')
    expect(completion_at(filename, [9, 33])).to include('something')
    expect(completion_at(filename, [13, 15])).to include('something')
  end

  it 'completes inside RSpec let-like methods' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        let(:something) { 1 }
        let(:other_thing) { someth }
      end
    RUBY

    expect(completion_at(filename, [2, 25])).to include('something')
  end

  describe 'configurations' do
    describe 'let_methods' do
      before(:each) do
        Solargraph::Rspec::Convention.instance_variable_set(:@config, nil)
        @global_path = File.realpath(Dir.mktmpdir)
        @orig_env = ENV.fetch('SOLARGRAPH_GLOBAL_CONFIG', nil)
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
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :model do
            let(:something) { 1 }
            let_it_be(:transaction) { described_class.new }
            let_it_be(:other_thing) { someth }

            it 'should do something' do
              tran
            end
          end
        RUBY

        assert_public_instance_method(api_map, 'RSpec::ExampleGroups::SomeNamespaceTransaction#transaction',
                                      ['undefined'])
        expect(completion_at(filename, [6, 7])).to include('transaction')
        expect(completion_at(filename, [3, 31])).to include('something')
      end
    end
  end
end
