class CreateItemCompanies < ActiveRecord::Migration[7.1]
  def change
    create_table :item_companies do |t|
      t.references :item, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true

      t.timestamps
    end

    add_index :item_companies, [:item_id, :company_id], unique: true
    # company_idのインデックスはt.referencesで自動的に作成されるため不要
  end
end
