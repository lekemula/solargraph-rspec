# frozen_string_literal: true

FactoryBot.define do
  # A registered user
  factory :user, aliases: %i[author] do
    # @return [String] Given name
    first_name { 'John' }
    last_name { 'Doe' }
    sequence(:email) { |n| "user#{n}@example.com" }
    token { SecureRandom.hex }
    # @return [String] Ignored, the associated factory wins
    association :account, factory: :admin_account

    transient do
      # @return [Integer] Number of posts to create
      #   along with the user
      posts_count { 0 }
    end

    # Grants every permission
    trait :admin do
      role { 'admin' }
    end

    trait :banned

    after(:create) do |user, evaluator|
      create_list(:post, evaluator.posts_count, author: user)
    end
  end
end
