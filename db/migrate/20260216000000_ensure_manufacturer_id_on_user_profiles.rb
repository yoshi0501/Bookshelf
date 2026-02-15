# frozen_string_literal: true

class EnsureManufacturerIdOnUserProfiles < ActiveRecord::Migration[7.1]
  def up
    return if column_exists?(:user_profiles, :manufacturer_id)

    add_reference :user_profiles, :manufacturer, foreign_key: true
  end

  def down
    remove_reference :user_profiles, :manufacturer, foreign_key: true if column_exists?(:user_profiles, :manufacturer_id)
  end
end
