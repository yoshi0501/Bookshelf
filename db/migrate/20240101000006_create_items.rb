class CreateItems < ActiveRecord::Migration[7.1]
  def change
    create_table :items do |t|
      t.references :company, null: false, foreign_key: true
      t.string :item_code, null: false
      t.string :name, null: false
      t.decimal :unit_price, precision: 12, scale: 2, null: false
      t.decimal :co2_per_unit, precision: 10, scale: 4, default: 0
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    add_index :items, [:company_id, :item_code], unique: true
    add_index :items, [:company_id, :is_active]
  end
end
