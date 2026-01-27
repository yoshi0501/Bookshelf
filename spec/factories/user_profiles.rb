# frozen_string_literal: true

FactoryBot.define do
  factory :user_profile do
    user
    company
    sequence(:name) { |n| "User #{n}" }
    phone { "090-1234-5678" }
    role { :normal }
    member_status { :active }

    trait :pending do
      member_status { :pending }
    end

    trait :rejected do
      member_status { :rejected }
    end

    trait :company_admin do
      role { :company_admin }
    end

    trait :internal_admin do
      role { :internal_admin }
    end
  end
end
