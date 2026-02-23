class DropBillingCentersTable < ActiveRecord::Migration[7.1]
  def up
    # billing_centersテーブルへの外部キー制約が既に削除されていることを確認
    # customersテーブルのbilling_center_idは既にcustomersテーブルへの自己参照に変更済み
    
    drop_table :billing_centers if table_exists?(:billing_centers)
  end

  def down
    # テーブルを再作成（必要に応じて）
    create_table :billing_centers do |t|
      t.references :company, null: false, foreign_key: true
      t.string :billing_code, null: false
      t.string :billing_name, null: false
      t.string :postal_code
      t.string :prefecture
      t.string :city
      t.string :address1
      t.string :address2
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    add_index :billing_centers, [:company_id, :billing_code], unique: true
    add_index :billing_centers, [:company_id, :is_active]
  end
end
