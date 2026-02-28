# frozen_string_literal: true

class RemoveSupervisorFromUserProfiles < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :user_profiles, column: :supervisor_id
    remove_column :user_profiles, :supervisor_id, :bigint
  end
end
