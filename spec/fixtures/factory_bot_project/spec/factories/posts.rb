# frozen_string_literal: true

FactoryBot.define do
  factory :post do
    title { 'Hello' }
    author
    association :editor, factory: %i[user admin]
  end
end
