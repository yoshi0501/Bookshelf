class CreateApprovalRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :approval_requests do |t|
      t.references :user_profile, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.text :review_comment

      t.timestamps
    end

    add_index :approval_requests, [:company_id, :status]
    add_index :approval_requests, :status
  end
end
