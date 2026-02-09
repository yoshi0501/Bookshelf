class AddBillingCenterToCustomers < ActiveRecord::Migration[7.1]
  def change
    unless index_exists?(:customers, :billing_center_id)
      add_reference :customers, :billing_center, null: true, foreign_key: true, index: true
    else
      # 既にカラムが存在する場合は、外部キー制約のみ追加
      add_foreign_key :customers, :billing_centers, column: :billing_center_id unless foreign_key_exists?(:customers, :billing_centers)
    end
  end
end
