class CreateIntegrationLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :integration_logs do |t|
      t.references :company, null: false, foreign_key: true
      t.references :order, null: true, foreign_key: true
      t.string :integration_type, null: false
      t.string :result, null: false
      t.text :error_message
      t.text :payload

      t.timestamps
    end

    add_index :integration_logs, [:company_id, :integration_type]
    add_index :integration_logs, [:company_id, :created_at]
  end
end
