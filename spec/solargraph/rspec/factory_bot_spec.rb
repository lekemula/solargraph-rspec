RSpec.describe Solargraph::Rspec::FactoryBot do
  describe '#extract_factories_from_ast' do
    let(:ast) do
      Solargraph::Parser.parse(
        <<~RUBY
          FactoryGirl.define do
            # @param factory_arg [String]
            # @param trans_three [Boolean] Some comment
            # @param added_attr [Boolean] Comment :3
            factory :person, aliases: [:alias_name_here], class: Abc do
              # @return [String] Example content
              first_name 'John'
              factory_arg 'Doe'
              # @return [String] Example content
              example_value { }

              sequence(:email) { |n| "email\#{n}@example.com" }

              add_attribute(:example) { 'Value' }
              add_attribute(:added_attr) { true }

              association :parent, factory: :some_table
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

              # Example comment
              trait :some_trait do
                after(:create) do
                end
              end
            end

            # Some comment
            factory :some_table do
              add_attribute(:to_create) { 'string' }
            end
          end
        RUBY
      )
    end
    let(:extracted) do
      Solargraph::Rspec::FactoryBot.instance.send(:extract_factories_from_ast, ast)
    end

    it 'interprets class from class: arg' do
      
    end

    it 'interprets class from factory name if theres no class: arg' do
    end

    it 'parses aliases' do
    end

    it 'gets all regular kw args' do
    end

    it 'gets transient kw args' do
    end

    it 'gets all the traits' do
    end

    it 'ignores callback functions' do
    end

    it 'parses add_attribute' do
    end

    it 'parses associations' do
    end

    it 'parses sequence' do
    end
  end
end
