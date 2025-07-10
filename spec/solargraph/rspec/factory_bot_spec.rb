RSpec.describe Solargraph::Rspec::FactoryBot do
  describe '#extract_factories_from_ast' do
    it 'extracts the right data (WIP)' do
      ast = Solargraph::Parser.parse(%(
        FactoryGirl.define do
          factory :person, aliases: [:alias_name_here], class: Abc do
            # @return [String] Example content
            first_name 'John'
            last_name  'Doe'
            sequence(:email) { |n| "email\#{n}@example.com" }
            # @return [String] Example content
            example_value { }
            add_attribute(:example) { 'Value' }

            # Example comment
            trait :with_domains do
              after(:create) do |person|
                create_list(:domain, 3, registrant_person: person)
              end
            end
          end
        end
      ))

      Solargraph::Rspec::FactoryBot.instance.send(:extract_factories_from_ast, ast)
    end
  end
end
