class CreateUserProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :user_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.references :company, null: true, foreign_key: true
      t.integer :role, null: false, default: 0
      t.integer :member_status, null: false, default: 0
      t.string :name, null: false
      t.string :phone

      t.timestamps
    end

    add_index :user_profiles, [:company_id, :role]
    add_index :user_profiles, [:company_id, :member_status]
  end
end
