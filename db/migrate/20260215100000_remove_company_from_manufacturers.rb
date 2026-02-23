# frozen_string_literal: true

class RemoveCompanyFromManufacturers < ActiveRecord::Migration[7.1]
  def up
    remove_foreign_key :manufacturers, :companies
    remove_index :manufacturers, name: "index_manufacturers_on_company_id_and_code"
    remove_index :manufacturers, name: "index_manufacturers_on_company_id_and_is_active"
    remove_index :manufacturers, column: :company_id
    remove_column :manufacturers, :company_id
    add_index :manufacturers, :code, unique: true
  end

  def down
    add_reference :manufacturers, :company, foreign_key: true
    remove_index :manufacturers, column: :code
    add_index :manufacturers, [:company_id, :code], unique: true
    add_index :manufacturers, [:company_id, :is_active]
  end
end
