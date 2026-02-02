# frozen_string_literal: true

FactoryBot.define do
  factory :customer do
    company
    sequence(:center_code) { |n| "CENTER#{n}" }
    sequence(:center_name) { |n| "Center #{n}" }
    postal_code { "123-4567" }
    prefecture { "Tokyo" }
    city { "Shibuya" }
    address1 { "1-2-3 Shibuya" }
    address2 { "Building A" }
    is_active { true }

    trait :inactive do
      is_active { false }
    end
  end
end
