# frozen_string_literal: true

# B2B Multi-tenant Order System - Seed Data
# 現在のバリデーションに準拠したデータを投入します。
# 実行: rails db:seed
# 既存データを消してから投入: RESET=1 rails db:seed
# DB をリセットしてから投入: rails db:seed:reset

# 共通パスワード（8文字以上・英数字混在・メールと異なる・ブラックリスト外）
SEED_PASSWORD = "SeedPass1"

if ENV["RESET"] == "1"
  puts "Resetting existing data..."
  # FK の依存順に削除
  OrderApprovalRequest.delete_all
  OrderLine.delete_all
  Order.delete_all
  IntegrationLog.delete_all
  ApprovalRequest.delete_all
  ItemCompany.delete_all
  # Item に紐づく Active Storage を削除
  ActiveStorage::Attachment.where(record_type: "Item").delete_all
  Item.delete_all
  Customer.delete_all
  UserProfile.delete_all
  User.delete_all
  Company.delete_all
  IssuerSetting.delete_all
  PaperTrail::Version.delete_all if defined?(PaperTrail)
  puts "  Done."
  puts ""
end

SEED_YEAR = 2026
SEED_JANUARY = Date.new(SEED_YEAR, 1, 1)..Date.new(SEED_YEAR, 1, 31)

puts "Creating companies (5 companies)..."

companies = []
5.times do |i|
  n = i + 1
  code = "C%03d" % n
  # order_prefix: A-Z0-9 のみ、最大10文字
  prefix = "C%02d" % n
  domain = "company#{n}.example.com"
  company = Company.find_or_create_by!(code: code) do |c|
    c.name = "サンプル会社#{n}"
    c.domains = [domain]
    c.order_prefix = prefix
    c.order_seq = 0
    c.is_active = true
  end
  companies << company
  puts "  Created company: #{company.name} (#{company.code})"
end

puts "Creating internal admin..."

internal_admin = User.find_or_initialize_by(email: "admin@system.example.com")
internal_admin.assign_attributes(
  password: SEED_PASSWORD,
  password_confirmation: SEED_PASSWORD,
  confirmed_at: Time.current
)
internal_admin.save!
internal_admin.user_profile&.destroy
internal_admin.create_user_profile!(
  company: nil,
  name: "システム管理者",
  role: :internal_admin,
  member_status: :active
)

puts "Creating customers (1 billing + 4 receiving centers per company)..."

company_billing_centers = {}
companies.each_with_index do |company, company_index|
  # 請求先: 郵便番号は 123-4567 形式
  billing_center = Customer.find_or_create_by!(company: company, center_code: "#{company.code}-BILL-001") do |c|
    c.center_name = "#{company.name} 本社（請求先）"
    c.postal_code = "100-%04d" % (company_index + 1)
    c.prefecture = %w[東京都 大阪府 愛知県 兵庫県 福岡県][company_index]
    c.city = %w[千代田区 大阪市 名古屋市 神戸市 福岡市][company_index]
    c.address1 = "#{company_index + 1}-1-1 サンプル町"
    c.is_billing_center = true
    c.is_active = true
  end
  company_billing_centers[company.id] = billing_center

  4.times do |i|
    center_code = "#{company.code}-REC-%03d" % (i + 1)
    Customer.find_or_create_by!(company: company, center_code: center_code) do |c|
      c.center_name = "#{company.name} 配送センター#{i + 1}"
      c.postal_code = "%03d-%04d" % [100 + (company_index % 90), i + 1]
      c.prefecture = %w[東京都 大阪府 愛知県 兵庫県 福岡県 北海道 宮城県 埼玉県 千葉県 神奈川県][(company_index + i) % 10]
      c.city = "サンプル市区#{i + 1}"
      c.address1 = "#{i + 1}-#{i + 2}-#{i + 3} 番地"
      c.billing_center_id = billing_center.id
      c.is_billing_center = false
      c.is_active = true
    end
  end
  puts "  Created 5 centers for #{company.name}"
end

puts "Creating items (5 items per company)..."

companies.each do |company|
  5.times do |i|
    item_code = "#{company.code}-ITM-%03d" % (i + 1)
    Item.find_or_create_by!(company: company, item_code: item_code) do |item|
      item.name = "#{company.name} 商品#{i + 1}"
      item.unit_price = (1000 + (i * 500) + rand(0..500))
      item.co2_per_unit = (0.5 + (i * 0.2) + rand(0.0..0.3)).round(2)
      item.cost_price = (item.unit_price * (0.5 + rand(0.0..0.3))).round(0)
      item.shipping_cost = rand(0..200)
      item.is_active = true
    end
  end
  puts "  Created 5 items for #{company.name}"
end

puts "Creating users (1 internal admin + 29 company users = 30 total)..."

company_users = {}
companies.each_with_index do |company, idx|
  domain = company.domains.first
  # 管理者1人（メールとパスワードを異なるものに）
  admin_email = "admin@#{domain}"
  admin_user = User.find_or_initialize_by(email: admin_email)
  admin_user.assign_attributes(
    password: SEED_PASSWORD,
    password_confirmation: SEED_PASSWORD,
    confirmed_at: Time.current
  )
  admin_user.save!
  admin_user.user_profile&.destroy
  admin_user.create_user_profile!(
    company: company,
    name: "#{company.name} 管理者",
    role: :company_admin,
    member_status: :active
  )
  company_users[company.id] = [admin_user]

  normal_count = (idx < 4) ? 5 : 4
  normal_count.times do |i|
    user_email = "user#{i + 1}@#{domain}"
    user = User.find_or_initialize_by(email: user_email)
    user.assign_attributes(
      password: SEED_PASSWORD,
      password_confirmation: SEED_PASSWORD,
      confirmed_at: Time.current
    )
    user.save!
    user.user_profile&.destroy
    user.create_user_profile!(
      company: company,
      name: "#{company.name} ユーザー#{i + 1}",
      role: :normal,
      member_status: :active
    )
    company_users[company.id] << user
  end
end

total_company_users = companies.sum { |c| company_users[c.id]&.size || 0 }
puts "  Created #{total_company_users} company users (+ 1 internal admin = #{total_company_users + 1} total)"

puts "Creating orders (~30 orders in January #{SEED_YEAR})..."

companies.each do |company|
  receiving_centers = Customer.where(company: company, is_billing_center: false).to_a
  items = Item.where(company: company).to_a
  next if receiving_centers.empty? || items.empty?

  6.times do |i|
    customer = receiving_centers.sample
    order_date = SEED_JANUARY.to_a.sample
    order_user = company_users[company.id]&.sample
    next unless order_user

    order = Order.create!(
      company: company,
      customer: customer,
      ordered_by_user: order_user,
      order_date: order_date,
      shipping_status: %i[shipped delivered].sample,
      ship_postal_code: customer.postal_code,
      ship_prefecture: customer.prefecture,
      ship_city: customer.city,
      ship_address1: customer.address1,
      ship_center_name: customer.center_name
    )

    rand(1..3).times do
      item = items.sample
      qty = rand(1..10)
      OrderLine.create!(
        company: company,
        order: order,
        item: item,
        quantity: qty,
        unit_price_snapshot: item.unit_price,
        cost_price_snapshot: item.cost_price.to_d,
        shipping_cost_snapshot: item.shipping_cost.to_d,
        amount: item.unit_price * qty,
        co2_amount: (item.co2_per_unit || 0) * qty
      )
    end
    order.recalculate_totals!
  end
  puts "  Created 6 orders for #{company.name} (January #{SEED_YEAR})"
end

puts ""
puts "Seed completed!"
puts ""
puts "Summary:"
puts "  Companies: #{Company.count}"
puts "  Customers (Centers): #{Customer.count} (Billing: #{Customer.billing_centers.count}, Receiving: #{Customer.receiving_centers.count})"
puts "  Items: #{Item.count}"
puts "  Orders: #{Order.count} (in January #{SEED_YEAR}: #{Order.where(order_date: SEED_JANUARY).count})"
puts "  Users: #{User.count}"
puts ""
puts "========== ログイン情報（共通パスワード: #{SEED_PASSWORD}） =========="
puts ""
puts "【システム管理者】"
puts "  ID: admin@system.example.com"
puts "  パスワード: #{SEED_PASSWORD}"
puts ""
companies.each do |company|
  domain = company.domains.first
  puts "【#{company.name}】"
  puts "  管理者  ID: admin@#{domain}  パスワード: #{SEED_PASSWORD}"
  puts "  ユーザー ID: user1@#{domain}  パスワード: #{SEED_PASSWORD}"
  puts ""
end
puts "=================================================================================="
