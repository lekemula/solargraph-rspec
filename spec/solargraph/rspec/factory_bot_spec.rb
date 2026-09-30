# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::FactoryBot do
  let(:project_root) { File.expand_path('../../fixtures/factory_bot_project', __dir__) }

  around do |example|
    Dir.chdir(project_root) { example.run }
  end

  describe '#pins' do
    let(:factory_bot) { described_class.new }
    let(:factories) { factory_bot.send(:factories) }
    let(:pins) { factory_bot.pins }

    # @param name [Symbol]
    # @return [Solargraph::Rspec::FactoryBot::FactoryData]
    def factory(name)
      factories.find { |f| f.factory_names.first == name }
    end

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

    it 'reads factories from the conventional locations' do
      expect(factories.map { |f| f.factory_names.first }).to contain_exactly(
        :admin_account, :guest_account, :draft, :moderator, :post, :user
      )
    end

    it 'interprets class from class: arg (when const)' do
      expect(factory(:admin_account).model_class).to eql('Admin::Account')
    end

    it 'interprets class from class: arg (when string)' do
      expect(factory(:guest_account).model_class).to eql('Admin::Account')
    end

    it 'interprets class from factory name if theres no class: arg' do
      expect(factory(:user).model_class).to eql('User')
    end

    it 'parses aliases' do
      expect(factory(:user).factory_names).to eql(%i[user author])
    end

    it 'gets traits' do
      expect(factory(:user).traits.map(&:name)).to eql(%i[admin banned])
    end

    it 'keeps the comment and location of each trait' do
      admin = factory(:user).traits.first

      expect(admin.comment).to eql('Grants every permission')
      expect(admin.location.filename).to eql(File.join(project_root, 'spec/factories/users.rb'))
      expect(admin.location.range.start.line).to eql(20)
    end

    it 'locates each signature at its factory definition' do
      location = find_factory_sig(:post).location

      expect(location.filename).to eql(File.join(project_root, 'spec/factories/posts.rb'))
      expect(location.range.start.line).to eql(6)
    end

    it 'returns a list of models from _list methods' do
      list = pins.find { |p| p.is_a?(Solargraph::Pin::Method) && p.name == 'create_list' }
      sig = list.signatures.find { |s| s.parameters.first.return_type.to_s == ':post' }

      expect(sig.return_type.to_s).to eql('Array<Post>')
      expect(sig.parameters.map(&:name).first(2)).to eql(%w[name amount])
    end

    describe 'inheritance' do
      it 'builds the parent class in nested factories' do
        expect(factory(:moderator).model_class).to eql('User')
      end

      it 'builds the parent class with parent: option' do
        expect(factory(:draft).model_class).to eql('Post')
      end

      it 'inherits the parent attributes and traits' do
        expect(factory(:moderator).kwargs).to include(:first_name, :permissions)
        expect(factory(:moderator).traits.map(&:name)).to eql(%i[admin banned])
      end

      it 'does not leak nested factory attributes into the parent' do
        expect(factory(:user).kwargs).not_to include(:permissions)
      end

      it 'inherits the parent attribute docs' do
        expect(find_factory_arg(:draft, :title).return_type.to_s).to eql('String')
      end
    end

    describe 'FactoryBot.modify' do
      it 'adds attributes to the modified factory' do
        expect(factory(:post).kwargs).to include(:title, :published)
        expect(find_factory_arg(:post, :published).return_type.to_s).to eql('Boolean')
      end
    end

    describe 'getting kw args' do
      it 'gets all regular kw args' do
        expect(factory(:user).kwargs).to include(:first_name, :last_name, :token)
      end

      it 'gets transient kw args' do
        expect(factory(:user).kwargs).to include(:posts_count)
      end

      it 'lists attributes redefined in traits once' do
        expect(factory(:admin_account).kwargs).to eql(%i[plan])
      end

      it 'gets kw args defined in traits' do
        expect(factory(:user).kwargs).to include(:role)
      end

      it 'ignores callbacks and calls within attribute values' do
        expect(factory(:user).kwargs).not_to include(:after, :create_list, :hex)
      end

      it 'parses sequence' do
        expect(factory(:user).kwargs).to include(:email)
      end

      it 'parses attributes defined via add_attribute' do
        expect(factory(:post).kwargs).to include(:body)
      end

      describe 'association' do
        it 'understands the return type with factory: param' do
          expect(find_factory_arg(:user, :account).return_type.to_s).to eql('Admin::Account')
        end

        it 'understands the return type without factory: param' do
          expect(find_factory_arg(:post, :user).return_type.to_s).to eql('User')
        end

        it 'understands the return type when factory: param is an alias' do
          expect(find_factory_arg(:post, :reviewer).return_type.to_s).to eql('User')
        end

        it 'understands array factory: param' do
          expect(find_factory_arg(:post, :editor).return_type.to_s).to eql('User')
        end

        it 'keeps the documentation of an association typed by its factory' do
          expect(find_factory_arg(:user, :account).documentation).to eql('Ignored, the associated factory wins')
        end
      end

      describe 'documentation' do
        it 'understands top level @param docs' do
          param = find_factory_arg(:post, :title)

          expect(param.return_type.to_s).to eql('String')
          expect(param.documentation).to eql('The headline')
        end

        it 'uses the model class as return type' do
          expect(find_factory_sig(:user).return_type.to_s).to eql('User')
        end

        it 'understands attribute level @return tags' do
          param = find_factory_arg(:user, :posts_count)

          expect(param.return_type.to_s).to eql('Integer')
          expect(param.documentation).to eql("Number of posts to create\nalong with the user")
        end

        it 'documents attributes from plain comments' do
          param = find_factory_arg(:moderator, :permissions)

          expect(param.documentation).to eql('What the moderator may do')
        end

        it 'documents attributes from @type tags' do
          param = find_factory_arg(:post, :body)

          expect(param.return_type.to_s).to eql('String')
          expect(param.documentation).to eql('Markdown content')
        end

        it 'documents traits' do
          param = find_factory_arg(:user, :traits)

          expect(param.documentation).to eql('`:admin` (Grants every permission), `:banned`')
        end

        it 'keeps the factory comments' do
          expect(find_factory_sig(:post).docstring.to_s).to start_with('A blog post')
        end
      end
    end
  end

  describe '#factory_parameter_pins' do
    let(:pins) { described_class.new.factory_parameter_pins }

    before do
      skip 'Solargraph without Pin::FactoryParameter' unless defined?(Solargraph::Pin::FactoryParameter)
    end

    # @return [Solargraph::Pin::FactoryParameter, nil]
    def factory_parameter(method_path, param_name, value)
      pins.find { |p| p.method_path == method_path && p.param_name == param_name && p.value == value }
    end

    it 'locates factory names and aliases at the factory definition' do
      %i[user author].each do |name|
        pin = factory_parameter('FactoryBot::Syntax::Methods#create', 'name', name)

        expect(pin.location.filename).to end_with('spec/factories/users.rb')
        expect(pin.location.range.start.line).to eq(4)
      end
    end

    it 'locates traits at the trait definition' do
      pin = factory_parameter('FactoryBot::Syntax::Methods#create_list', 'traits', :admin)

      expect(pin.decl).to eq(:restarg)
      expect(pin.location.range.start.line).to eq(20)
    end
  end

  describe 'in spec files' do
    let(:api_map) { Solargraph::ApiMap.new }
    let(:spec_file) { File.join(project_root, 'spec/models/user_spec.rb') }

    before do
      # For performance reasons, avoid solargraph loading all installed gems' YARDoc and RBS gem pins.
      allow(Solargraph::Rspec::Gems).to receive(:gem_names).and_return(%w[rspec])
    end

    # @param code [String]
    # @return [void]
    def load_spec(code)
      models = Dir['app/models/**/*.rb'].map { |file| parse_string(File.expand_path(file), File.read(file)) }

      load_sources(*models, parse_string(spec_file, code))
    end

    it 'completes factory methods in examples' do
      load_spec(<<~RUBY)
        RSpec.describe User do
          it 'works' do
            crea
          end
        end
      RUBY

      expect(completion_at(spec_file, [2, 8])).to include('create', 'create_list')
    end

    # Released Solargraph versions pick the first overload whose arity matches, whatever the literal argument
    #
    # @return [Boolean]
    def literal_overloads_supported?
      map = Solargraph::ApiMap.new
      map.map(parse_string('overloads.rb', <<~RUBY))
        # @overload pick(name)
        #   @param name [:a]
        #   @return [Integer]
        # @overload pick(name)
        #   @param name [:b]
        #   @return [String]
        def pick(name); end
        value = pick(:b)
      RUBY
      map.source_map('overloads.rb').locals.find { |l| l.name == 'value' }.probe(map).to_s == 'String'
    end

    it 'infers the model built by the named factory' do
      pending 'Solargraph matching overloads by literal argument' unless literal_overloads_supported?

      load_spec(<<~RUBY)
        RSpec.describe User do
          let(:user) { create(:user, :admin, first_name: 'Jane') }
          let(:posts) { create_list(:post, 2) }

          it 'works' do
            user.full
            posts.first.publ
            create(:admin_account).susp
          end
        end
      RUBY

      expect(completion_at(spec_file, [5, 13])).to include('full_name')
      expect(completion_at(spec_file, [6, 20])).to include('publish!')
      expect(completion_at(spec_file, [7, 30])).to include('suspend!')
    end

    it 'goes to the definition of factory names and traits' do
      skip 'Solargraph without Pin::FactoryParameter' unless defined?(Solargraph::Pin::FactoryParameter)

      load_spec(<<~RUBY)
        RSpec.describe User do
          let(:user) { create(:author, :banned, :admin) }
        end
      RUBY

      definition = lambda { |column|
        api_map.clip_at(spec_file, [1, column]).define.map do |pin|
          pin.location.range.start.line
        end
      }

      expect(definition.call(24)).to eq([4])
      expect(definition.call(33)).to eq([24])
      expect(definition.call(41)).to eq([20])
    end

    it 'offers one create signature per factory' do
      load_spec("RSpec.describe User do\nend\n")

      create = api_map.get_method_stack('FactoryBot::Syntax::Methods', 'create').first

      expect(create.signatures.map { |sig| sig.return_type.to_s }).to contain_exactly(
        'Admin::Account', 'Admin::Account', 'Post', 'Post', 'User', 'User'
      )
    end

    it 'prefers the factory methods over the ones documented by the factory_bot gem' do
      # A trimmed copy of factory_bot/syntax/methods.rb
      gem_source = parse_string('factory_bot/syntax/methods.rb', <<~RUBY)
        module FactoryBot
          module Syntax
            module Methods
              # @!method build(name, *traits_and_overrides, &block)
              #   @return [Object]
              # @!method create(name, *traits_and_overrides, &block)
              #   @return [Object]
              # @!method build_list(name, amount, *traits_and_overrides, &block)
              #   @return [Array]
              # @!method create_list(name, amount, *traits_and_overrides, &block)
              #   @return [Array]
            end
          end
        end
      RUBY
      models = Dir['app/models/**/*.rb'].map { |file| parse_string(File.expand_path(file), File.read(file)) }
      load_sources(gem_source, *models, parse_string(spec_file, "RSpec.describe User do\nend\n"))

      %w[build create build_list create_list].each do |method_name|
        first = api_map.get_method_stack('FactoryBot::Syntax::Methods', method_name).first

        expect(first.signatures.size).to be > 1, "expected the factory pin for #{method_name} first"
      end
    end
  end
end
