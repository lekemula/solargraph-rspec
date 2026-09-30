# frozen_string_literal: true

FactoryBot.define do
  factory :admin_account, class: Admin::Account do
    plan { 'free' }
  end

  factory :guest_account, class: 'Admin::Account' do
    plan { 'none' }
  end
end
