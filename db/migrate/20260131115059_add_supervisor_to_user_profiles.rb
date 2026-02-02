class AddSupervisorToUserProfiles < ActiveRecord::Migration[7.1]
  def change
    add_reference :user_profiles, :supervisor, null: true, foreign_key: { to_table: :user_profiles }, index: true
  end
end
