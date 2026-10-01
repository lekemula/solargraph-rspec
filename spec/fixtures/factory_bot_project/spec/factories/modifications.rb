# frozen_string_literal: true

FactoryBot.modify do
  factory :post do
    # @return [Boolean]
    published { false }
  end
end
