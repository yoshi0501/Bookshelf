# frozen_string_literal: true

class CreateManufacturers < ActiveRecord::Migration[7.1]
  def change
    create_table :manufacturers do |t|
      t.references :company, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :email
      t.string :phone
      t.string :postal_code
      t.string :prefecture
      t.string :city
      t.string :address1
      t.string :address2
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end

    add_index :manufacturers, [:company_id, :code], unique: true
    add_index :manufacturers, [:company_id, :is_active]
  end
end
