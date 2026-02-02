class CreateOrderApprovalRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :order_approval_requests do |t|
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.references :company, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.text :review_comment

      t.timestamps
    end

    add_index :order_approval_requests, [:company_id, :status]
    add_index :order_approval_requests, :status
  end
end
