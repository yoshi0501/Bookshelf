# frozen_string_literal: true

class AddPaymentTermsToManufacturersAndUserProfiles < ActiveRecord::Migration[7.1]
  def change
    add_column :manufacturers, :payment_terms, :string
    add_column :user_profiles, :payment_terms, :string
  end
end
