# frozen_string_literal: true

class AddManufacturerToUserProfiles < ActiveRecord::Migration[7.1]
  def change
    add_reference :user_profiles, :manufacturer, foreign_key: true
  end
end
