class CreateCompanies < ActiveRecord::Migration[7.1]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.jsonb :domains, null: false, default: []
      t.string :order_prefix, null: false
      t.integer :order_seq, null: false, default: 0
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    add_index :companies, :code, unique: true
    add_index :companies, :domains, using: :gin
    add_index :companies, :is_active
  end
end
