# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::SpecConfigurationWalker do
  describe '#extract_included_modules' do
    it 'extracts modules from RSpec.configure blocks' do
      ast = Solargraph::Parser.parse(%(
        RSpec.configure do |config|
          config.include ModuleName
          config.example OtherVal
          config.include(SubMod::Module)
        end
      ), 'spec_helper.rb')

      walker = described_class.new(ast, 'spec_helper.rb')
      modules = walker.extract_included_modules

      expect(modules.map(&:module_name)).to eq(%w[ModuleName SubMod::Module])
      expect(modules.map(&:file)).to all(eq('spec_helper.rb'))
    end

    it 'handles multiple RSpec.configure blocks' do
      ast = Solargraph::Parser.parse(%(
        RSpec.configure do |config|
          config.include FirstModule
        end

        RSpec.configure do |c|
          c.include SecondModule
        end
      ), 'spec_helper.rb')

      walker = described_class.new(ast, 'spec_helper.rb')
      modules = walker.extract_included_modules

      expect(modules.map(&:module_name)).to eq(%w[FirstModule SecondModule])
    end

    it 'ignores non-include calls' do
      ast = Solargraph::Parser.parse(%(
        RSpec.configure do |config|
          config.expect_with :rspec
          config.mock_with :rspec
          config.include OnlyThisOne
        end
      ), 'spec_helper.rb')

      walker = described_class.new(ast, 'spec_helper.rb')
      modules = walker.extract_included_modules

      expect(modules.map(&:module_name)).to eq(%w[OnlyThisOne])
    end

    it 'returns empty array when no includes found' do
      ast = Solargraph::Parser.parse(%(
        RSpec.configure do |config|
          config.expect_with :rspec
        end
      ), 'spec_helper.rb')

      walker = described_class.new(ast, 'spec_helper.rb')
      modules = walker.extract_included_modules

      expect(modules).to be_empty
    end
  end
end
