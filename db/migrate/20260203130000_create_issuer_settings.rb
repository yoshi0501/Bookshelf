# frozen_string_literal: true

class CreateIssuerSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :issuer_settings do |t|
      t.string :name, null: false, default: ""
      t.string :postal_code
      t.string :prefecture
      t.string :city
      t.string :address1
      t.string :address2
      t.string :phone
      t.string :fax
      t.string :registration_number
      t.string :bank_account_1
      t.string :bank_account_2
      t.timestamps
    end
  end
end
