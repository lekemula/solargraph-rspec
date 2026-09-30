# frozen_string_literal: true

FactoryBot.define do
  # A blog post
  #
  # @param title [String] The headline
  factory :post do
    title { 'Hello' }
    add_attribute(:body) { 'Lorem ipsum' }
    association :reviewer, factory: :author
    association :editor, factory: %i[user admin]
    association :user
    author
  end

  factory :draft, parent: :post do
    reason { 'WIP' }
  end
end
