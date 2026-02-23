# frozen_string_literal: true

class AddManufacturerToItems < ActiveRecord::Migration[7.1]
  def change
    add_reference :items, :manufacturer, foreign_key: true
  end
end
