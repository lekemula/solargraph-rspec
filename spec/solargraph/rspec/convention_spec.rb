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
                                  ['Class<::SomeNamespace::Transaction>']) do |pin|
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

    assert_class_method(api_map, 'RSpec::ExampleGroups::TestSomeNamespaceTransaction.it', [''])
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
      load_and_assert_type('let(:some_array) { [1, 2, 3] }', 'some_array', 'Array')
    end

    it 'infers type for some_hash' do
      load_and_assert_type("let(:some_hash) { { key: 'value' } }", 'some_hash', 'Hash')
    end

    it 'infers type for some_boolean' do
      load_and_assert_type('let(:some_boolean) { true }', 'some_boolean', 'Boolean')
    end

    it 'infers type for some_nil' do
      load_and_assert_type('let(:some_nil) { nil }', 'some_nil', 'nil')
    end

    it 'infers type for some_float' do
      load_and_assert_type('let(:some_float) { 1.0 }', 'some_float', 'Float')
    end

    it 'infers type for some_symbol' do
      load_and_assert_type('let(:some_symbol) { :symbol }', 'some_symbol', 'Symbol')
    end

    it 'infers type for some_object' do
      load_and_assert_type(<<~RUBY, 'some_object', 'MyClass')
        class MyClass; end
        let(:some_object) { MyClass.new }
      RUBY
    end

    it 'infers type for some_class' do
      load_and_assert_type('let(:some_class) { Class.new }', 'some_class', 'Class<BasicObject>')
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
        'Array'
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
        'nil'
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
        'Class<BasicObject>'
      )
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

      it 'does not raise an exception' do
        filename = File.expand_path('spec/models/some_namespace/transaction_spec.rb')
        file = load_string filename, <<~RUBY
          0-1i23981
        RUBY

        expect do
          load_sources(file)
        end.not_to raise_error
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

  describe 'helpers' do
    describe 'shoulda-matchers' do
      it 'completes active-model matchers' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :model do
            it 'completes active-model matchers' do
              allow_valu
              have_secur
              validate_a
              validate_a
              validate_c
              validate_e
              validate_i
              validate_l
              validate_n
              validate_p
            end
          end
        RUBY

        expect(completion_at(filename, [2, 15])).to include('allow_value')
        expect(completion_at(filename, [3, 15])).to include('have_secure_password')
        expect(completion_at(filename, [4, 15])).to include('validate_absence_of')
        expect(completion_at(filename, [5, 15])).to include('validate_acceptance_of')
        expect(completion_at(filename, [6, 15])).to include('validate_confirmation_of')
        expect(completion_at(filename, [7, 15])).to include('validate_exclusion_of')
        expect(completion_at(filename, [8, 15])).to include('validate_inclusion_of')
        expect(completion_at(filename, [9, 15])).to include('validate_length_of')
        expect(completion_at(filename, [10, 15])).to include('validate_numericality_of')
        expect(completion_at(filename, [11, 15])).to include('validate_presence_of')
      end

      it 'completes active-record matchers' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :model do
            it 'completes controller matchers' do
              accept_nested_attributes
              belon
              define_enum
              have_and_belong_to_
              have_delegated_
              have_db_co
              have_db_i
              have_implicit_order_co
              have_
              have_many_atta
              have
              have_one_atta
              have_readonly_attri
              have_rich_
              seria
              validate_uniquenes
              norma
              enc
            end
          end
        RUBY

        expect(completion_at(filename, [2, 5])).to include('accept_nested_attributes_for')
        expect(completion_at(filename, [3, 5])).to include('belong_to')
        expect(completion_at(filename, [4, 5])).to include('define_enum_for')
        expect(completion_at(filename, [5, 5])).to include('have_and_belong_to_many')
        # expect(completion_at(filename, [6, 5])).to include('have_delegated_type')
        expect(completion_at(filename, [7, 5])).to include('have_db_column')
        expect(completion_at(filename, [8, 5])).to include('have_db_index')
        expect(completion_at(filename, [9, 5])).to include('have_implicit_order_column')
        expect(completion_at(filename, [10, 5])).to include('have_many')
        expect(completion_at(filename, [11, 5])).to include('have_many_attached')
        expect(completion_at(filename, [12, 5])).to include('have_one')
        expect(completion_at(filename, [13, 5])).to include('have_one_attached')
        expect(completion_at(filename, [14, 5])).to include('have_readonly_attribute')
        expect(completion_at(filename, [15, 5])).to include('have_rich_text')
        expect(completion_at(filename, [16, 5])).to include('serialize')
        expect(completion_at(filename, [17, 5])).to include('validate_uniqueness_of')
        # expect(completion_at(filename, [18, 5])).to include('normalize')
        # expect(completion_at(filename, [19, 5])).to include('encrypt')
      end

      it 'completes controller matchers' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :model do
            it 'completes controller matchers' do
              filter_pa
              per
              redirect
              render_templ
              render_with_lay
              rescue_f
              respond_w
              ro
              set_sess
              set_fl
              use_after_act
              use_around_act
              use_before_act
            end
          end
        RUBY

        expect(completion_at(filename, [2, 5])).to include('filter_param')
        expect(completion_at(filename, [3, 5])).to include('permit')
        expect(completion_at(filename, [4, 5])).to include('redirect_to')
        expect(completion_at(filename, [5, 5])).to include('render_template')
        expect(completion_at(filename, [6, 5])).to include('render_with_layout')
        expect(completion_at(filename, [7, 5])).to include('rescue_from')
        expect(completion_at(filename, [8, 5])).to include('respond_with')
        expect(completion_at(filename, [9, 5])).to include('route')
        expect(completion_at(filename, [10, 5])).to include('set_session')
        expect(completion_at(filename, [11, 5])).to include('set_flash')
        expect(completion_at(filename, [12, 5])).to include('use_after_action')
        expect(completion_at(filename, [13, 5])).to include('use_around_action')
        expect(completion_at(filename, [14, 5])).to include('use_before_action')
      end
    end

    describe 'rspec-mocks' do
      it 'completes methods from rspec-mocks' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :model do
            let(:something) { double }

            it 'should do something' do
              allow(something).to rec
              allow(double).to receive_me
              my_double = doub
              my_double = inst
            end
          end
        RUBY

        expect(completion_at(filename, [4, 26])).to include('receive')
        expect(completion_at(filename, [5, 30])).to include('receive_message_chain')
        expect(completion_at(filename, [6, 18])).to include('double')
        expect(completion_at(filename, [7, 18])).to include('instance_double')
      end
    end

    describe 'rspec-rails' do
      # A model spec is a thin wrapper for an ActiveSupport::TestCase
      # See: https://api.rubyonrails.org/v5.2.8.1/classes/ActiveSupport/Testing/Assertions.html
      it 'completes model methods' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :model do
            it 'should do something' do
              assert_ch
              assert_di
              assert_no
              assert_no
              assert_no
              assert_no
            end
          end
        RUBY

        expect(completion_at(filename, [2, 5])).to include('assert_changes')
        expect(completion_at(filename, [3, 5])).to include('assert_difference')
        expect(completion_at(filename, [4, 5])).to include('assert_no_changes')
        expect(completion_at(filename, [5, 5])).to include('assert_no_difference')
        expect(completion_at(filename, [6, 5])).to include('assert_not')
        expect(completion_at(filename, [7, 5])).to include('assert_nothing_raised')
      end

      # @see [ActionController::TestCase::Behavior]
      it 'completes controller methods' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :controller do
            it 'should do something' do
              build_re
              controll
              delet
              generate
              ge
              hea
              patc
              pos
              proces
              pu
              query_pa
              setup_co
              requ
              request.ho
              respo
              response.bo
            end
          end
        RUBY

        expect(completion_at(filename, [2, 5])).to include('build_response')
        expect(completion_at(filename, [3, 5])).to include('controller_class_name')
        expect(completion_at(filename, [4, 5])).to include('delete')
        expect(completion_at(filename, [5, 5])).to include('generated_path')
        expect(completion_at(filename, [6, 5])).to include('get')
        expect(completion_at(filename, [7, 5])).to include('head')
        expect(completion_at(filename, [8, 5])).to include('patch')
        expect(completion_at(filename, [9, 5])).to include('post')
        expect(completion_at(filename, [10, 5])).to include('process')
        expect(completion_at(filename, [11, 5])).to include('put')
        expect(completion_at(filename, [12, 5])).to include('query_parameter_names')
        expect(completion_at(filename, [13, 5])).to include('setup_controller_request_and_response')
        expect(completion_at(filename, [14, 5])).to include('request')
        expect(completion_at(filename, [15, 13])).to include('host') # request.host
        expect(completion_at(filename, [16, 5])).to include('response')
        expect(completion_at(filename, [17, 14])).to include('body') # response.body
      end

      it 'completes ActiveSupport assertions' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :model do
            it 'should do something' do
              assert_cha
              assert_dif
              assert_no_
              assert_no_
              assert_no
              assert_not
              assert_rai
              assert_rai
              assert_tem
            end
          end
        RUBY

        expect(completion_at(filename, [2, 5])).to include('assert_changes')
        expect(completion_at(filename, [3, 5])).to include('assert_difference')
        expect(completion_at(filename, [4, 5])).to include('assert_no_changes')
        expect(completion_at(filename, [5, 5])).to include('assert_no_difference')
        expect(completion_at(filename, [6, 5])).to include('assert_not')
        expect(completion_at(filename, [7, 5])).to include('assert_nothing_raised')
        # expect(completion_at(filename, [8, 5])).to include('assert_raise')
        expect(completion_at(filename, [9, 5])).to include('assert_raises')
        expect(completion_at(filename, [10, 5])).to include('assert_template')
      end

      it 'completes ActiveSupport helpers' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :model do
            it 'should do something' do
              after_teardo
              freeze_ti
              trav
              travel_ba
              travel_
              file_fix
            end
          end
        RUBY

        expect(completion_at(filename, [2, 5])).to include('after_teardown')
        expect(completion_at(filename, [3, 5])).to include('freeze_time')
        expect(completion_at(filename, [4, 5])).to include('travel')
        expect(completion_at(filename, [5, 5])).to include('travel_back')
        expect(completion_at(filename, [6, 5])).to include('travel_to')
        expect(completion_at(filename, [7, 5])).to include('file_fixture')
      end

      it 'completes routing helpers' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :model do
            it 'should do something' do
              after_teardo
              freeze_ti
              trav
              travel_ba
              travel_
            end
          end
        RUBY
      end

      it 'completes mailer methods' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :mailer do
            it 'should do something' do
              assert_emai
              assert_enqu
              assert_no_e
              assert_no_e
            end
          end
        RUBY

        expect(completion_at(filename, [2, 5])).to include('assert_emails')
        expect(completion_at(filename, [3, 5])).to include('assert_enqueued_emails')
        expect(completion_at(filename, [4, 5])).to include('assert_no_emails')
        expect(completion_at(filename, [5, 5])).to include('assert_no_enqueued_emails')
      end

      it 'completes matchers from rspec-rails' do
        load_string filename, <<~RUBY
          RSpec.describe SomeNamespace::Transaction, type: :model do
            it 'should do something' do
              be_a_
              render_templ
              redirect
              route
              be_routa
              have_http_sta
              match_ar
              have_been_enque
              have_enqueued_
            end
          end
        RUBY

        expect(completion_at(filename, [2, 5])).to include('be_a_new')
        expect(completion_at(filename, [3, 5])).to include('render_template')
        expect(completion_at(filename, [4, 5])).to include('redirect_to')
        # expect(completion_at(filename, [5, 5])).to include('route_to')
        # expect(completion_at(filename, [6, 5])).to include('be_routable')
        expect(completion_at(filename, [7, 5])).to include('have_http_status')
        expect(completion_at(filename, [8, 5])).to include('match_array')
        expect(completion_at(filename, [9, 5])).to include('have_been_enqueued')
        expect(completion_at(filename, [10, 5])).to include('have_enqueued_job')
      end
    end
  end
end
