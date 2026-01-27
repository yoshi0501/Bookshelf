# frozen_string_literal: true

FactoryBot.define do
  factory :order_line do
    company
    order
    item
    quantity { 1 }
    unit_price_snapshot { 1000 }
    amount { quantity * unit_price_snapshot }
    co2_amount { 0.5 }

    after(:build) do |line|
      line.company ||= line.order&.company
      if line.item
        line.unit_price_snapshot ||= line.item.unit_price
        line.amount = line.quantity * line.unit_price_snapshot
        line.co2_amount = (line.item.co2_per_unit || 0) * line.quantity
      end
    end
  end
end
