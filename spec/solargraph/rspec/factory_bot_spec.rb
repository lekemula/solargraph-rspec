RSpec.describe Solargraph::Rspec::FactoryBot do
  describe '#extract_factories_from_ast' do
    let(:source_code) do
      <<~RUBY
        FactoryGirl.define do
          # Some factory
          #
          # @param factory_arg [String]
          # @param trans_three [Boolean] Some comment
          # @param added_attr [Boolean] Comment :3
          # @return [String] hehe I'm a fake evil comment >:)
          factory :person, aliases: [:alias_name_here], class: Abc do
            # @return [String] Example content
            first_name 'John'
            factory_arg 'Doe'
            # @return [String] Example content
            example_value { }

            # Some comment
            sequence(:seq_col) { |n| "email\#{n}@example.com" }

            # @return [String] Some example attribute comment
            add_attribute(:example) { 'Value' }
            add_attribute(:added_attr) { true }

            association :parent, factory: :some_table
            # @return [SomeBadType]
            association :some_table

            to_create { }
            after(:something) {}
            before(:something) {}
            callback(:something) {}

            transient do
              # @return [String]
              trans_one { 'value' }
              # @return [Number] Comment line 1
              #   Comment line 2
              trans_two 1
              trans_three true
            end

            trait :some_trait do
              after(:create) do
              end
            end
          end

          # Some comment
          factory :some_table do
            add_attribute(:to_create) { 'string' }

            association :ass, factory: :alias_name_here
            association :person
          end

          factory :other_table, class: 'Blah' do
          end
        end
      RUBY
    end

    before do
      Solargraph::Rspec::FactoryBot.reset
      allow(Dir).to receive(:glob).and_return(['factories.rb'])
      allow(File).to receive(:read).and_return(source_code)
    end

    let(:factories) { Solargraph::Rspec::FactoryBot.instance.send(:factories) }
    let(:pins) { Solargraph::Rspec::FactoryBot.instance.pins }

    # @return [Solargraph::Pin::Signature, nil]
    def find_factory_sig(factory_name)
      # @type [Solargraph::Pin::Method, nil]
      met = pins.find { |p| p.is_a?(Solargraph::Pin::Method) && p.name == 'create' }
      expect(met).not_to be_nil

      met.signatures.find { |p| p.parameters.first&.return_type.to_s.split(', ').include? ":#{factory_name}" }
    end

    # @return [Solargraph::Pin::Parameter, nil]
    def find_factory_arg(factory_name, param)
      sig = find_factory_sig(factory_name)
      expect(sig).not_to be_nil

      sig.parameters.find { |p| p.name == param.to_s }
    end

    it 'interprets class from class: arg' do
      expect(factories.first.model_class).to eql('Abc')
      expect(factories.first.factory_names).to include(:person)
    end

    it 'interprets class from factory name if theres no class: arg' do
      expect(factories[1].model_class).to eql('SomeTable')
      expect(factories[1].factory_names).to include(:some_table)
    end

    it 'parses aliases' do
      expect(factories[0].factory_names).to eql(%i[person alias_name_here])
    end

    describe 'getting kw args' do
      it 'gets all regular kw args' do
        # parses both these:
        #   column value
        #   column { value }
        expect(factories[0].kwargs).to include(*%i[first_name factory_arg example_value])
      end

      it 'gets transient kw args' do
        expect(factories[0].kwargs).to include(*%i[trans_one trans_two trans_three])
      end

      it 'ignores callback functions' do
        %w[to_create after before callback].each do |cb|
          expect(factories[0].kwargs).not_to include(cb), "Expected to ignore #{cb}, but didn't"
        end
      end

      it 'parses sequence' do
        expect(factories[0].kwargs).to include(:seq_col)
      end

      describe 'add_attribute' do
        it 'parses attributes defined via add_attribute' do
          expect(factories[0].kwargs).to include(:example, :added_attr)
          expect(factories[1].kwargs).to include(:to_create)
        end
      end

      describe 'association' do
        context 'when associated factory has a class: ' do
          it 'understands the return type with factory: param' do
            arg = find_factory_arg(:some_table, :ass)
            expect(arg).not_to be_nil
            expect(arg.return_type.to_s).to eql('Abc')
          end

          it 'understands the return type without factory: param' do
            arg = find_factory_arg(:some_table, :person)
            expect(arg).not_to be_nil
            expect(arg.return_type.to_s).to eql('Abc')
          end

          it 'understands the return type when factory: param is an alias' do
            arg = find_factory_arg(:some_table, :ass)
            expect(arg).not_to be_nil
            expect(arg.return_type.to_s).to eql('Abc')
          end

          it 'forces return_type' do
            arg = find_factory_arg(:person, :some_table)
            expect(arg).not_to be_nil
            expect(arg.return_type.to_s).to eql('SomeTable')
          end
        end

        context 'when associated factory has no class: param' do
          it 'understands the return type with factory: param' do
            arg = find_factory_arg(:person, :parent)
            expect(arg).not_to be_nil
            expect(arg&.return_type.to_s).to eql('SomeTable')
          end

          it 'understands the return type without factory: param' do
            arg = find_factory_arg(:person, :some_table)
            expect(arg).not_to be_nil
            expect(arg&.return_type.to_s).to eql('SomeTable')
          end
        end
      end

      describe 'documentation' do
        it 'should understand top level @param docs' do
          param = find_factory_arg(:person, :trans_three)

          expect(param).not_to be_nil
          expect(param.return_type.to_s).to eql('Boolean')
          expect(param.documentation).to eql('Some comment')
        end

        it 'should force return type on top level factory' do
          sig = find_factory_sig(:person)

          expect(sig).not_to be_nil
          expect(sig.return_type.to_s).to eql('Abc')
        end

        it 'should understand param level @return tags' do
          param = find_factory_arg(:person, :trans_two)

          expect(param).not_to be_nil
          expect(param.return_type.to_s).to eql('Number')
          expect(param.documentation).to eql("Comment line 1\nComment line 2")
        end

        it 'should understand docs for add_attribute' do
          param = find_factory_arg(:person, :example)

          expect(param).not_to be_nil
          expect(param.return_type.to_s).to eql('String')
          expect(param.documentation).to eql('Some example attribute comment')
        end
      end
    end

    it 'gets traits' do
      expect(factories[0].traits).to include(*%i[some_trait])
    end
  end
end
