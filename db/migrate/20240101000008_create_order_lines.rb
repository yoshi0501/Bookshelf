class CreateOrderLines < ActiveRecord::Migration[7.1]
  def change
    create_table :order_lines do |t|
      t.references :company, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.decimal :unit_price_snapshot, precision: 12, scale: 2, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.decimal :co2_amount, precision: 12, scale: 4, default: 0

      t.timestamps
    end

    add_index :order_lines, [:order_id, :item_id]
  end
end
