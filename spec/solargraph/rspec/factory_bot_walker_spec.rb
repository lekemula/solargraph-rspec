# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::FactoryBotWalker do
  let(:filename) { 'spec/factories.rb' }

  # @param code [String]
  # @yieldparam [Solargraph::Rspec::FactoryBotWalker]
  # @return [void]
  def walk_code(code)
    walker = described_class.new(Solargraph::Source.load_string(code, filename))

    yield walker

    walker.walk!
  end

  # @param code [String]
  # @return [Array<Solargraph::Rspec::FactoryBotWalker::Factory>]
  def factories_in(code)
    factories = []
    walk_code(code) { |walker| walker.on_factory { |factory| factories << factory } }
    factories
  end

  # @param code [String]
  # @return [Hash{Symbol => Array<Symbol>}] attribute names by factory name
  def attributes_in(code)
    attributes = Hash.new { |h, k| h[k] = [] }
    walk_code(code) do |walker|
      walker.on_attribute { |factory, attribute_name| attributes[factory.name] << attribute_name }
    end
    attributes
  end

  describe '#on_factory' do
    it 'yields factories in FactoryBot and FactoryGirl define blocks' do
      factories = factories_in(<<~RUBY)
        FactoryBot.define do
          factory :user do
          end
        end

        FactoryGirl.define do
          factory :post
        end
      RUBY

      expect(factories.map(&:names)).to eq([[:user], [:post]])
    end

    it 'yields factories in modify blocks' do
      factories = factories_in(<<~RUBY)
        FactoryBot.modify do
          factory :user do
          end
        end
      RUBY

      expect(factories.map(&:name)).to eq([:user])
    end

    it 'ignores factory calls outside define blocks' do
      factories = factories_in(<<~RUBY)
        factory :user do
        end
      RUBY

      expect(factories).to be_empty
    end

    it 'yields aliases after the factory name' do
      factories = factories_in(<<~RUBY)
        FactoryBot.define do
          factory :user, aliases: [:author, 'commenter'] do
          end
        end
      RUBY

      expect(factories.first.names).to eq(%i[user author commenter])
    end

    it 'yields the class: option when given as a constant, string or symbol' do
      factories = factories_in(<<~RUBY)
        FactoryBot.define do
          factory :admin, class: Admin::User do
          end
          factory :guest, class: '::Guest' do
          end
          factory :owner, class: :Owner do
          end
          factory :user do
          end
        end
      RUBY

      expect(factories.map(&:class_name)).to eq(['Admin::User', 'Guest', 'Owner', nil])
    end

    it 'yields the enclosing factory, or the parent: option, as parent' do
      factories = factories_in(<<~RUBY)
        FactoryBot.define do
          factory :user do
            factory :admin do
            end
          end
          factory :guest, parent: :user do
          end
        end
      RUBY

      expect(factories.to_h { |f| [f.name, f.parent] }).to eq(user: nil, admin: :user, guest: :user)
    end

    it 'yields the comments preceding the factory and its location' do
      factories = factories_in(<<~RUBY)
        FactoryBot.define do
          # A user
          # @return [User]
          factory :user do
          end
        end
      RUBY

      expect(factories.first.comments).to eq("A user\n@return [User]")
      expect(factories.first.location_range).to eq(Solargraph::Range.from_to(3, 2, 4, 5))
    end
  end

  describe '#on_attribute' do
    it 'yields dynamic and static attributes' do
      attributes = attributes_in(<<~RUBY)
        FactoryBot.define do
          factory :user do
            first_name { 'John' }
            last_name 'Doe'
          end
        end
      RUBY

      expect(attributes[:user]).to eq(%i[first_name last_name])
    end

    it 'yields sequences, add_attribute and transient attributes' do
      attributes = attributes_in(<<~RUBY)
        FactoryBot.define do
          factory :user do
            sequence(:email) { |n| "user\#{n}@example.com" }
            add_attribute(:method) { 'GET' }

            transient do
              upcased { false }
            end

            ignore do
              legacy_transient { false }
            end
          end
        end
      RUBY

      expect(attributes[:user]).to eq(%i[email method upcased legacy_transient])
    end

    it 'yields attributes declared in traits for the enclosing factory' do
      attributes = attributes_in(<<~RUBY)
        FactoryBot.define do
          factory :user do
            trait :admin do
              role { 'admin' }
            end
          end
        end
      RUBY

      expect(attributes[:user]).to eq(%i[role])
    end

    it 'ignores callbacks and method calls within attribute values' do
      attributes = attributes_in(<<~RUBY)
        FactoryBot.define do
          factory :user do
            token { SecureRandom.hex }
            email { "\#{first_name}@example.com" }

            after(:create) { |user| user.confirm! }
            before(:create) { |user| user.touch }
            callback(:after_stub) { |user| user.stub! }
            to_create { |user| user.save! }
            skip_create
            initialize_with { new(attributes) }
          end
        end
      RUBY

      expect(attributes[:user]).to eq(%i[token email])
    end

    it 'yields attributes of nested factories for the nested factory only' do
      attributes = attributes_in(<<~RUBY)
        FactoryBot.define do
          factory :user do
            name { 'John' }

            factory :admin do
              role { 'admin' }
            end
          end
        end
      RUBY

      expect(attributes).to eq(user: %i[name], admin: %i[role])
    end

    it 'yields the comments preceding the attribute' do
      comments = {}
      walk_code(<<~RUBY) do |walker|
        FactoryBot.define do
          factory :user do
            # @return [String] The first name
            first_name { 'John' }
            last_name { 'Doe' }
          end
        end
      RUBY
        walker.on_attribute { |_factory, name, attribute_comments| comments[name] = attribute_comments }
      end

      expect(comments).to eq(first_name: '@return [String] The first name', last_name: '')
    end
  end

  describe '#on_association' do
    # @param code [String]
    # @return [Array<Array(Symbol, Symbol, Symbol)>] factory name, attribute name and target factory name
    def associations_in(code)
      associations = []
      walk_code(code) do |walker|
        walker.on_association do |factory, attribute_name, target_factory_name|
          associations << [factory.name, attribute_name, target_factory_name]
        end
      end
      associations
    end

    it 'yields the association target factory' do
      associations = associations_in(<<~RUBY)
        FactoryBot.define do
          factory :post do
            association :user
            association :author, factory: :user
            association :editor, factory: %i[user admin]
            reviewer factory: :user
          end
        end
      RUBY

      expect(associations).to eq(
        [
          %i[post user user],
          %i[post author user],
          %i[post editor user],
          %i[post reviewer user]
        ]
      )
    end

    it 'also yields associations as attributes' do
      attributes = attributes_in(<<~RUBY)
        FactoryBot.define do
          factory :post do
            association :author, factory: :user
          end
        end
      RUBY

      expect(attributes[:post]).to eq(%i[author])
    end
  end

  describe '#on_trait' do
    it 'yields traits with their comments' do
      traits = []
      walk_code(<<~RUBY) do |walker|
        FactoryBot.define do
          factory :user do
            # Grants admin rights
            trait :admin do
              role { 'admin' }
            end

            trait :banned do
            end
          end
        end
      RUBY
        walker.on_trait { |factory, trait_name, comments| traits << [factory.name, trait_name, comments] }
      end

      expect(traits).to eq([[:user, :admin, 'Grants admin rights'], [:user, :banned, '']])
    end
  end

  describe '#after_walk' do
    it 'is called once walking is done' do
      called = 0
      walk_code("FactoryBot.define { factory :user }\n") do |walker|
        walker.after_walk { called += 1 }
      end

      expect(called).to eq(1)
    end
  end
end
