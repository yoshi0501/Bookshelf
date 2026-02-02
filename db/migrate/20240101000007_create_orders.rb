class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.references :company, null: false, foreign_key: true
      t.string :order_no, null: false
      t.date :order_date, null: false
      t.references :ordered_by_user, null: false, foreign_key: { to_table: :users }
      t.references :customer, null: false, foreign_key: true

      # Shipping address snapshot from customer
      t.string :ship_postal_code
      t.string :ship_prefecture
      t.string :ship_city
      t.string :ship_address1
      t.string :ship_address2
      t.string :ship_center_name

      # Shipping status
      t.integer :shipping_status, null: false, default: 0
      t.date :ship_date
      t.string :tracking_no
      t.date :delivered_date

      # Totals
      t.decimal :total_amount, precision: 14, scale: 2, null: false, default: 0
      t.decimal :co2_total, precision: 12, scale: 4, default: 0

      t.timestamps
    end

    add_index :orders, [:company_id, :order_no], unique: true
    add_index :orders, [:company_id, :order_date]
    add_index :orders, [:company_id, :shipping_status]
    add_index :orders, :order_date
    add_index :orders, :shipping_status
  end
end
