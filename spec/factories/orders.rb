# frozen_string_literal: true

FactoryBot.define do
  factory :order do
    company
    customer
    association :ordered_by_user, factory: :user
    order_date { Date.current }
    shipping_status { :draft }
    total_amount { 0 }
    co2_total { 0 }

    after(:build) do |order|
      order.company ||= order.customer&.company
      order.order_no ||= order.company&.generate_next_order_no!
    end

    trait :confirmed do
      shipping_status { :confirmed }
    end

    trait :shipped do
      shipping_status { :shipped }
      tracking_no { "TRACK123456" }
      ship_date { Date.current }
    end

    trait :delivered do
      shipping_status { :delivered }
      tracking_no { "TRACK123456" }
      ship_date { Date.current - 2.days }
      delivered_date { Date.current }
    end

    trait :cancelled do
      shipping_status { :cancelled }
    end

    trait :with_lines do
      transient do
        line_count { 3 }
      end

      after(:create) do |order, evaluator|
        evaluator.line_count.times do
          item = create(:item, company: order.company)
          create(:order_line, order: order, item: item, company: order.company)
        end
        order.recalculate_totals!
      end
    end
  end
end
