# frozen_string_literal: true

FactoryBot.define do
  factory :item do
    company
    sequence(:item_code) { |n| "ITEM#{n}" }
    sequence(:name) { |n| "Product #{n}" }
    unit_price { 1000 }
    co2_per_unit { 0.5 }
    is_active { true }

    trait :inactive do
      is_active { false }
    end

    trait :expensive do
      unit_price { 100_000 }
    end
  end
end
