# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::SpecHelperInclude do
  describe '#extract_included_modules' do
    it 'should pull included modules' do
      ast = Solargraph::Parser.parse(%(
        Rspec.configure do |config|
          config.include ModuleName
          config.example OtherVal
          config.include(SubMod::Module)
        end
      ))

      # @type [Array<Solargraph::Rspec::SpecHelperInclude::INCLUDED_MODULE_DATA>]
      modules = Solargraph::Rspec::SpecHelperInclude.instance.send(:extract_included_modules, ast, 'spec_helper.rb')

      expect(modules.map(&:module_name)).to eql(%w[ModuleName SubMod::Module])
    end
  end
end
