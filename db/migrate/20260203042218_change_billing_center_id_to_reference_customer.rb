class ChangeBillingCenterIdToReferenceCustomer < ActiveRecord::Migration[7.1]
  def up
    # 既存のbilling_centersテーブルへの外部キー制約を削除
    remove_foreign_key :customers, :billing_centers if foreign_key_exists?(:customers, :billing_centers)
    
    # billing_center_idの外部キー制約をcustomersテーブルへの参照に変更
    # まず、既存の外部キー制約名を確認して削除
    execute <<-SQL
      ALTER TABLE customers 
      DROP CONSTRAINT IF EXISTS customers_billing_center_id_fk;
    SQL
    
    # customersテーブルへの自己参照外部キーを追加
    add_foreign_key :customers, :customers, column: :billing_center_id, on_delete: :restrict
  end

  def down
    # customersテーブルへの自己参照外部キーを削除
    remove_foreign_key :customers, :customers if foreign_key_exists?(:customers, column: :billing_center_id)
    
    # billing_centersテーブルへの外部キーを復元（billing_centersテーブルが存在する場合）
    if table_exists?(:billing_centers)
      add_foreign_key :customers, :billing_centers, column: :billing_center_id
    end
  end
end
