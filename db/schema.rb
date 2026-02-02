# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_02_02_093616) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "approval_requests", force: :cascade do |t|
    t.bigint "user_profile_id", null: false
    t.bigint "company_id", null: false
    t.integer "status", default: 0, null: false
    t.bigint "reviewed_by_id"
    t.datetime "reviewed_at"
    t.text "review_comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "status"], name: "index_approval_requests_on_company_id_and_status"
    t.index ["company_id"], name: "index_approval_requests_on_company_id"
    t.index ["reviewed_by_id"], name: "index_approval_requests_on_reviewed_by_id"
    t.index ["status"], name: "index_approval_requests_on_status"
    t.index ["user_profile_id"], name: "index_approval_requests_on_user_profile_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.jsonb "domains", default: [], null: false
    t.string "order_prefix", null: false
    t.integer "order_seq", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_companies_on_code", unique: true
    t.index ["domains"], name: "index_companies_on_domains", using: :gin
    t.index ["is_active"], name: "index_companies_on_is_active"
  end

  create_table "customers", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "center_code", null: false
    t.string "center_name", null: false
    t.string "postal_code"
    t.string "prefecture"
    t.string "city"
    t.string "address1"
    t.string "address2"
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "center_code"], name: "index_customers_on_company_id_and_center_code", unique: true
    t.index ["company_id", "is_active"], name: "index_customers_on_company_id_and_is_active"
    t.index ["company_id"], name: "index_customers_on_company_id"
  end

  create_table "integration_logs", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "order_id"
    t.string "integration_type", null: false
    t.string "result", null: false
    t.text "error_message"
    t.text "payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "created_at"], name: "index_integration_logs_on_company_id_and_created_at"
    t.index ["company_id", "integration_type"], name: "index_integration_logs_on_company_id_and_integration_type"
    t.index ["company_id"], name: "index_integration_logs_on_company_id"
    t.index ["order_id"], name: "index_integration_logs_on_order_id"
  end

  create_table "item_companies", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_item_companies_on_company_id"
    t.index ["item_id", "company_id"], name: "index_item_companies_on_item_id_and_company_id", unique: true
    t.index ["item_id"], name: "index_item_companies_on_item_id"
  end

  create_table "items", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "item_code", null: false
    t.string "name", null: false
    t.decimal "unit_price", precision: 12, scale: 2, null: false
    t.decimal "co2_per_unit", precision: 10, scale: 4, default: "0.0"
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "is_active"], name: "index_items_on_company_id_and_is_active"
    t.index ["company_id", "item_code"], name: "index_items_on_company_id_and_item_code", unique: true
    t.index ["company_id"], name: "index_items_on_company_id"
  end

  create_table "order_approval_requests", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "company_id", null: false
    t.integer "status", default: 0, null: false
    t.bigint "reviewed_by_id"
    t.datetime "reviewed_at"
    t.text "review_comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "status"], name: "index_order_approval_requests_on_company_id_and_status"
    t.index ["company_id"], name: "index_order_approval_requests_on_company_id"
    t.index ["order_id"], name: "index_order_approval_requests_on_order_id", unique: true
    t.index ["reviewed_by_id"], name: "index_order_approval_requests_on_reviewed_by_id"
    t.index ["status"], name: "index_order_approval_requests_on_status"
  end

  create_table "order_lines", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "order_id", null: false
    t.bigint "item_id", null: false
    t.integer "quantity", null: false
    t.decimal "unit_price_snapshot", precision: 12, scale: 2, null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.decimal "co2_amount", precision: 12, scale: 4, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_order_lines_on_company_id"
    t.index ["item_id"], name: "index_order_lines_on_item_id"
    t.index ["order_id", "item_id"], name: "index_order_lines_on_order_id_and_item_id"
    t.index ["order_id"], name: "index_order_lines_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "order_no", null: false
    t.date "order_date", null: false
    t.bigint "ordered_by_user_id", null: false
    t.bigint "customer_id", null: false
    t.string "ship_postal_code"
    t.string "ship_prefecture"
    t.string "ship_city"
    t.string "ship_address1"
    t.string "ship_address2"
    t.string "ship_center_name"
    t.integer "shipping_status", default: 0, null: false
    t.date "ship_date"
    t.string "tracking_no"
    t.date "delivered_date"
    t.decimal "total_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "co2_total", precision: 12, scale: 4, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "order_date"], name: "index_orders_on_company_id_and_order_date"
    t.index ["company_id", "order_no"], name: "index_orders_on_company_id_and_order_no", unique: true
    t.index ["company_id", "shipping_status"], name: "index_orders_on_company_id_and_shipping_status"
    t.index ["company_id"], name: "index_orders_on_company_id"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["order_date"], name: "index_orders_on_order_date"
    t.index ["ordered_by_user_id"], name: "index_orders_on_ordered_by_user_id"
    t.index ["shipping_status"], name: "index_orders_on_shipping_status"
  end

  create_table "user_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "company_id"
    t.integer "role", default: 0, null: false
    t.integer "member_status", default: 0, null: false
    t.string "name", null: false
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "supervisor_id"
    t.index ["company_id", "member_status"], name: "index_user_profiles_on_company_id_and_member_status"
    t.index ["company_id", "role"], name: "index_user_profiles_on_company_id_and_role"
    t.index ["company_id"], name: "index_user_profiles_on_company_id"
    t.index ["supervisor_id"], name: "index_user_profiles_on_supervisor_id"
    t.index ["user_id"], name: "index_user_profiles_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "password_changed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["password_changed_at"], name: "index_users_on_password_changed_at"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.jsonb "object"
    t.jsonb "object_changes"
    t.datetime "created_at"
    t.bigint "company_id"
    t.string "request_uuid"
    t.string "ip_address"
    t.string "user_agent"
    t.index ["company_id"], name: "index_versions_on_company_id"
    t.index ["created_at"], name: "index_versions_on_created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["whodunnit"], name: "index_versions_on_whodunnit"
  end

  add_foreign_key "approval_requests", "companies"
  add_foreign_key "approval_requests", "user_profiles"
  add_foreign_key "approval_requests", "users", column: "reviewed_by_id"
  add_foreign_key "customers", "companies"
  add_foreign_key "integration_logs", "companies"
  add_foreign_key "integration_logs", "orders"
  add_foreign_key "item_companies", "companies"
  add_foreign_key "item_companies", "items"
  add_foreign_key "items", "companies"
  add_foreign_key "order_approval_requests", "companies"
  add_foreign_key "order_approval_requests", "orders"
  add_foreign_key "order_approval_requests", "users", column: "reviewed_by_id"
  add_foreign_key "order_lines", "companies"
  add_foreign_key "order_lines", "items"
  add_foreign_key "order_lines", "orders"
  add_foreign_key "orders", "companies"
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "users", column: "ordered_by_user_id"
  add_foreign_key "user_profiles", "companies"
  add_foreign_key "user_profiles", "user_profiles", column: "supervisor_id"
  add_foreign_key "user_profiles", "users"
end
