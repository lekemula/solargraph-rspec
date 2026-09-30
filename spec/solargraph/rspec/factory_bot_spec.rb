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
      expect(factory(:user).traits).to eql(%i[admin banned])
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
        expect(factory(:moderator).traits).to eql(%i[admin banned])
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

        it 'keeps the factory comments' do
          expect(find_factory_sig(:post).docstring.to_s).to start_with('A blog post')
        end
      end
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

    it 'offers one create signature per factory' do
      load_spec("RSpec.describe User do\nend\n")

      create = api_map.get_method_stack('FactoryBot::Syntax::Methods', 'create').first

      expect(create.signatures.map { |sig| sig.return_type.to_s }).to contain_exactly(
        'Admin::Account', 'Admin::Account', 'Post', 'Post', 'User', 'User'
      )
    end
  end
end
