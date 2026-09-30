# frozen_string_literal: true

FactoryBot.define do
  factory :admin_account, class: Admin::Account do
    plan { 'free' }

    trait :pro do
      plan { 'pro' }
    end
  end

  factory :guest_account, class: 'Admin::Account' do
    plan { 'none' }
  end
end
