# frozen_string_literal: true

class AddInvoiceFieldsToCompanies < ActiveRecord::Migration[7.1]
  def change
    add_column :companies, :postal_code, :string
    add_column :companies, :prefecture, :string
    add_column :companies, :city, :string
    add_column :companies, :address1, :string
    add_column :companies, :address2, :string
    add_column :companies, :phone, :string
    add_column :companies, :fax, :string
    add_column :companies, :registration_number, :string
    add_column :companies, :bank_account_1, :string
    add_column :companies, :bank_account_2, :string
  end
end
