class AddIsBillingCenterToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :is_billing_center, :boolean, null: false, default: false
    add_index :customers, [:company_id, :is_billing_center]
  end
end
