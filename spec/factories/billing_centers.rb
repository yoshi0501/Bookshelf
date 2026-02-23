FactoryBot.define do
  factory :billing_center do
    company { nil }
    billing_code { "MyString" }
    billing_name { "MyString" }
    postal_code { "MyString" }
    prefecture { "MyString" }
    city { "MyString" }
    address1 { "MyString" }
    address2 { "MyString" }
    is_active { false }
  end
end
