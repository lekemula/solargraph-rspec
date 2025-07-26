# frozen_string_literal: true

RSpec.describe SomeNamespace::Transaction, type: :model do
  let(:user) { create(:user) }
  let(:transaction) { described_class.new }

  it 'should do something' do
    use
  end
end
