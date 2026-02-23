# frozen_string_literal: true

class AddShippingCarrierToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :shipping_carrier, :string, limit: 255
  end
end
