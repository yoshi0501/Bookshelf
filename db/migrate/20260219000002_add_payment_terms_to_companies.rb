# frozen_string_literal: true

class AddPaymentTermsToCompanies < ActiveRecord::Migration[7.1]
  def change
    add_column :companies, :payment_terms, :string
  end
end
