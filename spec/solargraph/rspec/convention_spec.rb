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

    assert_public_instance_method(api_map, 'RSpec::ExampleGroups::TestSomeNamespaceTransaction#described_class',
                                  ['Class<SomeNamespace::Transaction>']) do |pin|
      expect(pin.location.filename).to eq(filename)
      expect(pin.location.range.to_hash).to eq(
        { start: { line: 0, character: 15 }, end: { line: 0, character: 41 } }
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
      'RSpec::ExampleGroups::TestSomeNamespaceTransaction#transaction',
      ['undefined']
    ) do |pin|
      expect(pin.location.range.to_hash).to eq(
        { start: { line: 1, character: 2 }, end: { line: 1, character: 23 } }
      )
    end
    assert_public_instance_method(
      api_map,
      'RSpec::ExampleGroups::TestSomeNamespaceTransaction#something',
      ['undefined']
    ) do |pin|
      expect(pin.location.range.to_hash).to eq(
        { start: { line: 2, character: 2 }, end: { line: 2, character: 17 } }
      )
    end
    assert_public_instance_method(api_map, 'RSpec::ExampleGroups::TestSomeNamespaceTransaction#something_else',
                                  ['undefined'])
    assert_public_instance_method(
      api_map,
      'RSpec::ExampleGroups::TestSomeNamespaceTransaction::NestedContext#nested_something',
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

  # @see https://rspec.info/features/3-12/rspec-core/subject/one-liner-syntax/
  it 'generates method for one-liner expectations' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        subject(:transaction) { described_class.new }

        it { is_expected.to be_a(SomeNamespace::Transaction) }
        it { should be_a(SomeNamespace::Transaction) }
        it { should_not be_a(String)  }
      end
    RUBY

    subject_location = { start: { line: 1, character: 2 }, end: { line: 1, character: 23 } }

    assert_public_instance_method(
      api_map,
      'RSpec::ExampleGroups::TestSomeNamespaceTransaction#is_expected',
      ['RSpec::Expectations::ExpectationTarget']
    ) { |pin| expect(pin.location.range.to_hash).to eq(subject_location) }

    assert_public_instance_method(
      api_map,
      'RSpec::ExampleGroups::TestSomeNamespaceTransaction#should',
      ['RSpec::Matchers::BuiltIn::PositiveOperatorMatcher']
    ) { |pin| expect(pin.location.range.to_hash).to eq(subject_location) }

    assert_public_instance_method(
      api_map,
      'RSpec::ExampleGroups::TestSomeNamespaceTransaction#should_not',
      ['RSpec::Matchers::BuiltIn::NegativeOperatorMatcher']
    ) { |pin| expect(pin.location.range.to_hash).to eq(subject_location) }
  end

  it 'generates let methods with do/end block' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        let(:something) do
          "something"
        end

        let!(:other_thing) do
          2
        end

        let(:todo) do # "do" keyword overlap
          {
            'todo' => 'end' # "end" keyword overlap
          }
        end
      end
    RUBY

    assert_public_instance_method_inferred_type(
      api_map,
      'RSpec::ExampleGroups::TestSomeNamespaceTransaction#something',
      'String'
    )
    assert_public_instance_method_inferred_type(
      api_map,
      'RSpec::ExampleGroups::TestSomeNamespaceTransaction#other_thing',
      'Integer'
    )
    assert_public_instance_method_inferred_type(
      api_map,
      'RSpec::ExampleGroups::TestSomeNamespaceTransaction#todo',
      'Hash'
    )
  end

  it 'generates implicit subject method' do
    load_string filename, <<~RUBY
      RSpec.describe SomeNamespace::Transaction, type: :model do
        it 'should do something' do
          sub
        end

        context 'nested context with nameless subject' do
          subject { 1 }

          it 'overrides the implicit subject' do
            sub
          end
        end
      end
    RUBY

    assert_public_instance_method(api_map, 'RSpec::ExampleGroups::TestSomeNamespaceTransaction#subject',
                                  ['SomeNamespace::Transaction'])
    expect(completion_at(filename, [2, 6])).to include('subject')
    assert_public_instance_method_inferred_type(
      api_map,
      'RSpec::ExampleGroups::TestSomeNamespaceTransaction::NestedContextWithNamelessSubject#subject',
      'Integer'
    )
    expect(completion_at(filename, [9, 9])).to include('subject')
  end

  it 'does not generate implicit subject when describing a string instead of a class' do
    load_string filename, <<~RUBY
      RSpec.describe 'some text description', type: :model do
        it 'should do something' do
          sub
        end
      end
    RUBY

    expect(api_map.pins.any? do |pin|
      pin.name == 'subject' && pin.namespace == 'RSpec::ExampleGroups::TestSomeTextDescription'
    end).to be false
  end

  # Regression test: prevents errors when described_class is manually overridden with a let
  it 'handles manually overridden described_class without errors' do
    load_string filename, <<~RUBY
      RSpec.describe 'some text description', type: :model do
        let(:described_class) { SomeNamespace::Transaction }

        it 'should do something' do
          sub
        end
      end
    RUBY

    expect(api_map.pins.any? do |pin|
      pin.name == 'subject' && pin.namespace == 'RSpec::ExampleGroups::TestSomeTextDescription'
    end).to be false
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

    assert_namespace(api_map, 'RSpec::ExampleGroups::TestSomeNamespaceTransaction')
    assert_namespace(api_map, 'RSpec::ExampleGroups::TestSomeNamespaceTransaction::DescribingSomething')
    assert_namespace(api_map,
                     'RSpec::ExampleGroups::TestSomeNamespaceTransaction::DescribingSomething::WhenSomeContext')
    assert_namespace(api_map,
                     'RSpec::ExampleGroups::TestSomeNamespaceTransaction::DescribingSomething::TESTSomeSymbols')
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

  describe 'type inference' do
    def load_and_assert_type(let_declaration, let_name, expected_type)
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          #{let_declaration}
        end
      RUBY

      assert_public_instance_method_inferred_type(
        api_map,
        "RSpec::ExampleGroups::TestSomeNamespaceTransaction##{let_name}",
        expected_type
      )
    end

    it 'infers type for described_class.new' do
      skip 'FIXME: Why it doesn\'t work for `described_class.new`?'
      load_and_assert_type('let(:transaction) { described_class.new }', 'transaction', 'SomeNamespace::Transaction')
    end

    it 'infers type for subject' do
      load_and_assert_type('subject(:transaction) { 1 }', 'transaction', 'Integer')
    end

    it 'infers type for some_integer' do
      load_and_assert_type('let(:some_integer) { 1 }', 'some_integer', 'Integer')
    end

    it 'infers type for indirect_integer' do
      load_and_assert_type(<<-RUBY, 'indirect_integer', 'Integer')
        let(:some_integer) { 1 }
        let(:indirect_integer) { some_integer }
      RUBY
    end

    it 'infers type for some_string' do
      load_and_assert_type("let(:some_string) { 'string' }", 'some_string', 'String')
    end

    it 'infers type for some_array' do
      load_and_assert_type('let(:some_array) { [1, 2, 3] }', 'some_array', 'Array<Integer>')
    end

    it 'infers type for some_hash' do
      load_and_assert_type("let(:some_hash) { { key: 'value' } }", 'some_hash', 'Hash')
    end

    it 'infers type for some_boolean' do
      load_and_assert_type('let(:some_boolean) { true }', 'some_boolean', 'Boolean')
    end

    it 'infers type for some_nil' do
      load_and_assert_type('let(:some_nil) { nil }', 'some_nil', 'NilClass')
    end

    it 'infers type for some_float' do
      load_and_assert_type('let(:some_float) { 1.0 }', 'some_float', 'Float')
    end

    it 'infers type for some_symbol' do
      load_and_assert_type('let(:some_symbol) { :symbol }', 'some_symbol', 'Symbol')
    end

    it 'infers type for some_object' do
      # @todo Refactor spec to use load_and_assert_type once https://github.com/castwide/solargraph/pull/1008 is merged.
      # @see https://github.com/lekemula/solargraph-rspec/pull/16#issuecomment-3148564258
      load_string filename, <<~RUBY
        class MyClass; end

        RSpec.describe SomeNamespace::Transaction, type: :model do
          let(:some_object) { MyClass.new }
        end
      RUBY

      assert_public_instance_method_inferred_type(
        api_map,
        'RSpec::ExampleGroups::TestSomeNamespaceTransaction#some_object',
        'MyClass'
      )
    end

    it 'infers type for some_class' do
      # FIXME: once https://github.com/castwide/solargraph/pull/786 gets released
      # load_and_assert_type('let(:some_class) { Class.new }', 'some_class', 'Class<BasicObject>')
      load_and_assert_type('let(:some_class) { Class.new }', 'some_class', 'Class')
    end

    it 'infers type for some_module' do
      load_and_assert_type('let(:some_module) { Module.new }', 'some_module', 'Module')
    end

    it 'infers types for let methods' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          let(:transaction) { described_class.new }
          let(:some_integer) { 1 }
          let(:indirect_integer) { some_integer }
          let(:some_string) { 'string' }
          let(:some_array) { [1, 2, 3] }
          let(:some_hash) { { key: 'value' } }
          let(:some_boolean) { true }
          let(:some_nil) { nil }
          let(:some_float) { 1.0 }
          let(:some_symbol) { :symbol }
          let(:some_object) { MyClass.new }
          let(:some_class) { Class.new }
          let(:some_module) { Module.new }

          it 'should do something' do
            trans
            some_int
            indirec
            some_str
            some_arr
            some_has
            some_bool
            some_ni
            some_flo
            some_sym
            some_obj
            some_cla
            some_mod
          end
        end

        class MyClass; end
      RUBY

      # FIXME: Why it doesn't work for `describe_class.new`?
      # assert_public_instance_method_inferred_type(
      #   api_map,
      #   'RSpec::ExampleGroups::TestSomeNamespaceTransaction#transaction',
      #   'SomeNamespace::Transaction'
      # )
      assert_public_instance_method_inferred_type(
        api_map,
        'RSpec::ExampleGroups::TestSomeNamespaceTransaction#some_integer',
        'Integer'
      )
      assert_public_instance_method_inferred_type(
        api_map,
        'RSpec::ExampleGroups::TestSomeNamespaceTransaction#indirect_integer',
        'Integer'
      )
      assert_public_instance_method_inferred_type(
        api_map,
        'RSpec::ExampleGroups::TestSomeNamespaceTransaction#some_string',
        'String'
      )
      assert_public_instance_method_inferred_type(
        api_map,
        'RSpec::ExampleGroups::TestSomeNamespaceTransaction#some_array',
        'Array<Integer>'
      )
      assert_public_instance_method_inferred_type(
        api_map,
        'RSpec::ExampleGroups::TestSomeNamespaceTransaction#some_hash',
        'Hash'
      )
      assert_public_instance_method_inferred_type(
        api_map,
        'RSpec::ExampleGroups::TestSomeNamespaceTransaction#some_boolean',
        'Boolean'
      )
      assert_public_instance_method_inferred_type(
        api_map,
        'RSpec::ExampleGroups::TestSomeNamespaceTransaction#some_nil',
        'NilClass'
      )
      assert_public_instance_method_inferred_type(
        api_map,
        'RSpec::ExampleGroups::TestSomeNamespaceTransaction#some_float',
        'Float'
      )
      assert_public_instance_method_inferred_type(
        api_map,
        'RSpec::ExampleGroups::TestSomeNamespaceTransaction#some_symbol',
        'Symbol'
      )
      assert_public_instance_method_inferred_type(
        api_map,
        'RSpec::ExampleGroups::TestSomeNamespaceTransaction#some_object',
        'MyClass'
      )
      assert_public_instance_method_inferred_type(
        api_map,
        'RSpec::ExampleGroups::TestSomeNamespaceTransaction#some_class',
        # FIXME: once https://github.com/castwide/solargraph/pull/786 gets released
        # 'Class<BasicObject>'
        'Class'
      )
    end

    describe 'on variables' do
      it 'should parse result of a method defined in an example' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :model do
            it 'some example' do
              # @return [Numeric]
              def example_method
              end

              result = example_method
            end
          end
        RUBY

        var_pin = expect_local_variable_type('result', 'Numeric')
        # This is mostly important of includes outside an include pin (ie. https://github.com/lekemula/solargraph-rspec/pull/13)
        expect(var_pin.namespace).to eql('RSpec::ExampleGroups::TestSomeNamespaceTransaction')
      end

      it 'should parse result of a method defined in a context' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :model do
            # @return [String]
            def example_method
            end

            it 'some example' do
              result = example_method
            end
          end
        RUBY

        var_pin = expect_local_variable_type('result', 'String')
        expect(var_pin.namespace).to eql('RSpec::ExampleGroups::TestSomeNamespaceTransaction')
      end

      it 'should parse result of a module method included in an example' do
        load_string filename, <<~RUBY
          module SomeModule
            # @return [String]
            def example_method
            end
          end

          RSpec.describe SomeNamespace::Transaction, type: :model do
            it 'some example' do
              include SomeModule

              result = example_method
            end
          end
        RUBY

        var_pin = expect_local_variable_type('result', 'String')
        expect(var_pin.namespace).to eql('RSpec::ExampleGroups::TestSomeNamespaceTransaction')
      end

      it 'should parse result of a module method included in a context' do
        load_string filename, <<~RUBY
          module SomeModule
            # @return [Numeric]
            def example_method
            end
          end

          RSpec.describe SomeNamespace::Transaction, type: :model do
            include SomeModule

            it 'some example' do
              result = example_method
            end
          end
        RUBY

        var_pin = expect_local_variable_type('result', 'Numeric')
        expect(var_pin.namespace).to eql('RSpec::ExampleGroups::TestSomeNamespaceTransaction')
      end
    end
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

        assert_public_instance_method(api_map, 'RSpec::ExampleGroups::TestSomeNamespaceTransaction#transaction',
                                      ['undefined'])
        expect(completion_at(filename, [6, 7])).to include('transaction')
        expect(completion_at(filename, [3, 31])).to include('something')
      end
    end

    describe 'example_methods' do
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
            example_methods:
              - my_example
        YAML
      end

      it 'generates method for additional example-like methods' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :model do
            let(:transaction) { described_class.new }

            my_example 'should do something' do
              transaction
            end
          end
        RUBY

        assert_public_instance_method(api_map, 'RSpec::ExampleGroups::TestSomeNamespaceTransaction#transaction',
                                      ['undefined'])
        expect(completion_at(filename, [4, 7])).to include('transaction')
      end
    end
  end

  describe 'error handling' do
    context 'not in debug mode' do
      before do
        allow(Solargraph.logger).to receive(:warn).and_return(true)
        allow_any_instance_of(
          Solargraph::Rspec::Correctors::ContextBlockNamespaceCorrector
        ).to receive(:correct).and_raise(StandardError)
      end

      around do |example|
        ENV['SOLARGRAPH_DEBUG'] = nil
        example.run
        ENV['SOLARGRAPH_DEBUG'] = 'true'
      end

      it 'does not raise an exception and it logs instead' do
        allow(Solargraph.logger).to receive(:warn)
        filename = File.expand_path('spec/models/some_namespace/transaction_spec.rb')
        file = load_string filename, <<~RUBY
          0-1i23981
        RUBY

        expect do
          load_sources(file)
        end.not_to raise_error

        expect(Solargraph.logger).to have_received(:warn).with(/\[RSpec\] Error processing/).at_least(:once)
      end

      it 'logs via solargraph logger' do
        filename = File.expand_path('spec/models/some_namespace/transaction_spec.rb')
        load_string filename, <<~RUBY
          0-1i23981
        RUBY
        expect(Solargraph.logger).to have_received(:warn).with(/\[RSpec\] Error processing/).at_least(:once)
      end
    end
  end
end
