# frozen_string_literal: true

class AddTrackingToOrderLines < ActiveRecord::Migration[7.1]
  def change
    add_column :order_lines, :shipping_carrier, :string, limit: 255
    add_column :order_lines, :tracking_no, :string
    add_column :order_lines, :ship_date, :date
  end
end
