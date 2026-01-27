# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123456" }
    password_confirmation { "password123456" }
    confirmed_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :with_profile do
      transient do
        company { nil }
        role { :normal }
        member_status { :active }
      end

      after(:create) do |user, evaluator|
        user.user_profile&.destroy
        create(:user_profile,
          user: user,
          company: evaluator.company,
          role: evaluator.role,
          member_status: evaluator.member_status
        )
      end
    end
  end
end
