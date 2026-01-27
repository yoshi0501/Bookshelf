# frozen_string_literal: true

FactoryBot.define do
  factory :approval_request do
    user_profile
    company { user_profile.company }
    status { :pending }

    trait :approved do
      status { :approved }
      reviewed_by { create(:user) }
      reviewed_at { Time.current }
    end

    trait :rejected do
      status { :rejected }
      reviewed_by { create(:user) }
      reviewed_at { Time.current }
      review_comment { "Rejected for testing" }
    end
  end
end
