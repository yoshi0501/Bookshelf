# frozen_string_literal: true

FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Company #{n}" }
    sequence(:code) { |n| "COMP#{n}" }
    sequence(:order_prefix) { |n| "ORD#{n}" }
    domains { ["example#{rand(1000)}.com"] }
    order_seq { 0 }
    is_active { true }

    trait :inactive do
      is_active { false }
    end

    trait :with_domain do
      transient do
        domain { "example.com" }
      end

      domains { [domain] }
    end
  end
end
