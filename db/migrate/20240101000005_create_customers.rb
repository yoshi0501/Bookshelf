class CreateCustomers < ActiveRecord::Migration[7.1]
  def change
    create_table :customers do |t|
      t.references :company, null: false, foreign_key: true
      t.string :center_code, null: false
      t.string :center_name, null: false
      t.string :postal_code
      t.string :prefecture
      t.string :city
      t.string :address1
      t.string :address2
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    add_index :customers, [:company_id, :center_code], unique: true
    add_index :customers, [:company_id, :is_active]
  end
end
