# frozen_string_literal: true

class CreateAccessLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :access_logs do |t|
      t.references :user, null: true, foreign_key: true
      t.string :user_name, null: false, default: ""
      t.string :user_email
      t.references :company, null: true, foreign_key: true
      t.string :controller_path, null: false
      t.string :action_name, null: false
      t.string :request_path, null: false
      t.string :request_method, limit: 10, null: false
      t.string :ip_address
      t.string :user_agent, limit: 500

      t.timestamps
    end

    add_index :access_logs, :created_at
    add_index :access_logs, [:company_id, :created_at]
    add_index :access_logs, [:user_id, :created_at]
  end
end
