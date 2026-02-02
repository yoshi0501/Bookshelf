# PaperTrail versions table for audit trail
class CreateVersions < ActiveRecord::Migration[7.1]
  def change
    create_table :versions do |t|
      t.string   :item_type, null: false
      t.bigint   :item_id,   null: false
      t.string   :event,     null: false
      t.string   :whodunnit
      t.jsonb    :object
      t.jsonb    :object_changes
      t.datetime :created_at

      # Custom columns for multi-tenant audit
      t.bigint   :company_id
      t.string   :request_uuid
      t.string   :ip_address
      t.string   :user_agent
    end

    add_index :versions, %i[item_type item_id]
    add_index :versions, :company_id
    add_index :versions, :whodunnit
    add_index :versions, :created_at
  end
end
