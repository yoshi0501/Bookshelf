# frozen_string_literal: true

class AddCostAndShippingToItems < ActiveRecord::Migration[7.1]
  def change
    add_column :items, :cost_price, :decimal, precision: 12, scale: 2, default: 0, null: false
    add_column :items, :shipping_cost, :decimal, precision: 12, scale: 2, default: 0, null: false
  end
end
