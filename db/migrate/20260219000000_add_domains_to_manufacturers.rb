# frozen_string_literal: true

class AddDomainsToManufacturers < ActiveRecord::Migration[7.1]
  def change
    add_column :manufacturers, :domains, :jsonb, default: [], null: false
    add_index :manufacturers, :domains, using: :gin
  end
end
