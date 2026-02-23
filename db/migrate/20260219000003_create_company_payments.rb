# frozen_string_literal: true

class CreateCompanyPayments < ActiveRecord::Migration[7.1]
  def change
    create_table :company_payments do |t|
      t.references :company, null: false, foreign_key: true
      t.integer :year, null: false
      t.integer :month, null: false
      t.date :due_date
      t.date :paid_at
      t.decimal :amount, precision: 14, scale: 2
      t.string :memo

      t.timestamps
    end

    add_index :company_payments, [:company_id, :year, :month], unique: true
    add_index :company_payments, :paid_at
  end
end
