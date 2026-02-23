# frozen_string_literal: true

class AddCostSnapshotsToOrderLines < ActiveRecord::Migration[7.1]
  def change
    add_column :order_lines, :cost_price_snapshot, :decimal, precision: 12, scale: 2, default: 0, null: false
    add_column :order_lines, :shipping_cost_snapshot, :decimal, precision: 12, scale: 2, default: 0, null: false
  end
end
