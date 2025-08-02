# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::RSpecConfigure do
  describe '#extract_included_modules' do
    it 'should pull included modules' do
      ast = Solargraph::Parser.parse(%(
        Rspec.configure do |config|
          config.include ModuleName
          config.example OtherVal
          config.include(SubMod::Module)
        end
      ))

      # @type [Array<Solargraph::Rspec::RSpecConfigure::IncludedModule>]
      modules = Solargraph::Rspec::RSpecConfigure.instance.send(:extract_included_modules, ast, 'spec_helper.rb')

      expect(modules.map(&:module_name)).to eql(%w[ModuleName SubMod::Module])
    end
  end
end
