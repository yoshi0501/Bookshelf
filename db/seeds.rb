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
  AccessLog.delete_all if ActiveRecord::Base.connection.table_exists?("access_logs")
  Manufacturer.delete_all if ActiveRecord::Base.connection.table_exists?("manufacturers")
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
  confirmed_at: Time.current,
  password_changed_at: Time.current
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

# メーカーはプラットフォーム共通マスタ（会社に属さず、1メーカーが複数会社に供給）
platform_manufacturers = []
if ActiveRecord::Base.connection.table_exists?("manufacturers")
  puts "Creating manufacturers (platform-wide, 4 makers)..."
  %w[M01 M02 M03 M04].each do |code|
    m = Manufacturer.find_or_create_by!(code: code) do |mc|
      mc.name = "共通メーカー#{code}"
      mc.email = "ship-#{code.downcase}@platform.example.com"
      mc.phone = "03-1234-#{code[-1]}000"
      mc.is_active = true
    end
    platform_manufacturers << m
  end
  puts "  Created #{platform_manufacturers.size} platform manufacturers"
else
  puts "Skipping manufacturers (manufacturers table not found). Run: bin/rails db:migrate"
end

puts "Creating items (5 items per company)..."

companies.each do |company|
  # 複数会社の商品が同じメーカー（M01,M02等）を参照しうる
  manufacturers = platform_manufacturers
  5.times do |i|
    item_code = "#{company.code}-ITM-%03d" % (i + 1)
    manufacturer = manufacturers[i % manufacturers.size] if manufacturers.any?
    Item.find_or_create_by!(company: company, item_code: item_code) do |item|
      item.name = "#{company.name} 商品#{i + 1}"
      item.unit_price = (1000 + (i * 500) + rand(0..500))
      item.co2_per_unit = (0.5 + (i * 0.2) + rand(0.0..0.3)).round(2)
      item.cost_price = (item.unit_price * (0.5 + rand(0.0..0.3))).round(0)
      item.shipping_cost = rand(0..200)
      item.manufacturer_id = manufacturer&.id
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
    confirmed_at: Time.current,
    password_changed_at: Time.current
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
      confirmed_at: Time.current,
      password_changed_at: Time.current
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

# メーカーアカウント（プラットフォーム共通・会社に属さない）— 作成後パスワードを Encryptor で固定してログインを保証
if !ActiveRecord::Base.connection.table_exists?("manufacturers")
  puts "※ メーカーアカウントはスキップ（manufacturers テーブルがありません。bin/rails db:migrate を実行してください）"
elsif !UserProfile.column_names.include?("manufacturer_id")
  puts "※ メーカーアカウントはスキップ（user_profiles.manufacturer_id がありません。bin/rails db:migrate を実行してください）"
elsif platform_manufacturers.empty?
  puts "※ メーカーアカウントはスキップ（メーカーが0件です。上記で manufacturers を作成してください）"
end
if UserProfile.column_names.include?("manufacturer_id") && platform_manufacturers.any?
  puts "Creating manufacturer logins (maker-m01〜m04@platform.example.com)..."
  platform_manufacturers.each do |manufacturer|
    safe_code = manufacturer.code.downcase.gsub(/[^a-z0-9]/, "-")
    maker_email = "maker-#{safe_code}@platform.example.com"
    maker_user = User.find_or_initialize_by(email: maker_email)
    maker_user.assign_attributes(
      password: SEED_PASSWORD,
      password_confirmation: SEED_PASSWORD,
      confirmed_at: Time.current,
      password_changed_at: Time.current,
      failed_attempts: 0,
      locked_at: nil,
      unlock_token: nil
    )
    maker_user.save!
    maker_user.user_profile&.destroy
    maker_user.create_user_profile!(
      company: nil,
      manufacturer: manufacturer,
      name: "#{manufacturer.name} 担当",
      role: :normal,
      member_status: :active
    )
    # ログイン確実化: Encryptor でパスワードを直接設定（コールバックに依存しない）
    enc = Devise::Encryptor.digest(User, SEED_PASSWORD)
    maker_user.update_columns(
      encrypted_password: enc,
      confirmed_at: Time.current,
      password_changed_at: Time.current,
      failed_attempts: 0,
      locked_at: nil,
      unlock_token: nil,
      updated_at: Time.current
    )
    maker_user.reload
    puts "  Created manufacturer login: #{maker_email} (#{manufacturer.name}) — パスワード: #{SEED_PASSWORD}"
  end
end

total_company_users = companies.sum { |c| company_users[c.id]&.size || 0 }
maker_count = UserProfile.column_names.include?("manufacturer_id") ? platform_manufacturers.size : 0
puts "  Created #{total_company_users} company users#{maker_count.positive? ? " + #{maker_count} manufacturer users" : ""} (+ 1 internal admin)"

puts "Creating orders (~30 orders in January #{SEED_YEAR}, 発送依頼ページ用に confirmed/shipped を含む)..."

companies.each do |company|
  receiving_centers = Customer.where(company: company, is_billing_center: false).to_a
  # 発送依頼に表示されるよう、メーカー紐づき商品を優先（items は既に manufacturer_id 付きで作成済み）
  items = Item.where(company: company).to_a
  next if receiving_centers.empty? || items.empty?

  6.times do |i|
    customer = receiving_centers.sample
    order_date = SEED_JANUARY.to_a.sample
    order_user = company_users[company.id]&.sample
    next unless order_user

    # 発送依頼一覧に表示されるステータス（confirmed=確認済み, shipped=出荷済み）。delivered は発送依頼対象外
    status = %i[confirmed shipped shipped].sample
    order = Order.create!(
      company: company,
      customer: customer,
      ordered_by_user: order_user,
      order_date: order_date,
      shipping_status: status,
      ship_postal_code: customer.postal_code,
      ship_prefecture: customer.prefecture,
      ship_city: customer.city,
      ship_address1: customer.address1,
      ship_center_name: customer.center_name
    )

    # 明細はメーカー紐づき商品を含む（items の多くは manufacturer_id あり）
    rand(1..4).times do
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
  puts "  Created 6 orders for #{company.name} (January #{SEED_YEAR}, 発送依頼対象: confirmed/shipped)"
end

# 発送依頼が1件も入らない場合に備え、テスト用に必ず1件以上は発送依頼対象の注文を作る
if platform_manufacturers.any?
  items_with_maker = Item.joins(:company).where.not(manufacturer_id: nil).to_a
  if items_with_maker.any?
    companies_with_centers = companies.select do |c|
      Customer.where(company: c, is_billing_center: false).exists? && company_users[c.id]&.any?
    end
    if companies_with_centers.any?
      shipping_request_count_before = Order.where(shipping_status: %i[confirmed shipped]).joins(order_lines: :item).where.not(items: { manufacturer_id: nil }).distinct.count
      if shipping_request_count_before < 1
        company = companies_with_centers.first
        receiving_centers = Customer.where(company: company, is_billing_center: false).to_a
        order_user = company_users[company.id]&.first
        company_items_with_maker = items_with_maker.select { |it| it.company_id == company.id }

        unless receiving_centers.empty? || order_user.nil? || company_items_with_maker.empty?
          puts "Creating 発送依頼テスト用 orders (発送依頼が0件のため最低1件を追加)..."
          2.times do |i|
          customer = receiving_centers[i % receiving_centers.size]
          order = Order.create!(
            company: company,
            customer: customer,
            ordered_by_user: order_user,
            order_date: SEED_JANUARY.to_a.sample,
            shipping_status: %i[confirmed shipped][i],
            ship_postal_code: customer.postal_code,
            ship_prefecture: customer.prefecture,
            ship_city: customer.city,
            ship_address1: customer.address1,
            ship_center_name: customer.center_name
          )
          [company_items_with_maker.first, company_items_with_maker.second].compact.uniq.each do |item|
            qty = rand(2..5)
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
          puts "  発送依頼テスト用 order #{order.order_no} created (status: #{order.shipping_status})"
        end
        end
      end
    end
  end

  # M01 に紐づく発送依頼が必ず1件以上あるようにする（maker-m01@platform.example.com でテストできる）
  m01 = Manufacturer.find_by(code: "M01")
  if m01
    m01_order_ids = OrderLine.joins(:item).where(items: { manufacturer_id: m01.id }).distinct.pluck(:order_id)
    m01_shipping_count = Order.where(id: m01_order_ids).where(shipping_status: %i[confirmed shipped]).where(order_date: SEED_JANUARY).count
    if m01_shipping_count < 1
      company = companies.first
      receiving_centers = Customer.where(company: company, is_billing_center: false).to_a
      order_user = company_users[company.id]&.first
      m01_items = Item.where(company: company, manufacturer_id: m01.id).to_a
      if receiving_centers.any? && order_user && m01_items.any?
        puts "Creating M01 発送依頼テスト用 order..."
        customer = receiving_centers.first
        order = Order.create!(
          company: company,
          customer: customer,
          ordered_by_user: order_user,
          order_date: Date.current, # 当月で表示されるように
          shipping_status: :confirmed,
          ship_postal_code: customer.postal_code,
          ship_prefecture: customer.prefecture,
          ship_city: customer.city,
          ship_address1: customer.address1,
          ship_center_name: customer.center_name
        )
        m01_items.first(2).each do |item|
          qty = rand(2..5)
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
        puts "  M01 発送依頼用 order #{order.order_no} created (maker-m01@platform.example.com で表示されます)"
      end
    end
  end
end

# アクセスログのサンプル（確認用）
if ActiveRecord::Base.connection.table_exists?("access_logs")
  begin
    puts "Creating access logs (sample for verification)..."
    base_time = Time.current - 3.days
    order = Order.first
    order2 = Order.second
    customer1 = Customer.first
    customer2 = Customer.second
    item = Item.first
    manufacturer = ActiveRecord::Base.connection.table_exists?("manufacturers") ? Manufacturer.first : nil
    company = Company.first
    profile = UserProfile.where.not(role: :internal_admin).first

    admin_user = internal_admin
    company_admin = company ? (company_users[company.id]&.first) : nil

    # 必須データがない場合はスキップ
    unless admin_user && company
      puts "  Skipped (admin_user or company missing)"
    else
      # target_summary あり/なし両方。OrderApprovalRequest 等に依存しない
      entries = [
        ["orders", "create", "/orders", "POST", order ? "発注 #{order.order_no}" : nil],
        ["orders", "update", "/orders/#{order&.id}", "PATCH", order ? "発注 #{order.order_no}" : nil],
        ["orders", "ship", "/orders/#{order&.id}/ship", "PATCH", order ? "発注 #{order.order_no}" : nil],
        ["orders", "deliver", "/orders/#{order2&.id}", "PATCH", order2 ? "発注 #{order2.order_no}" : nil],
        ["orders", "cancel", "/orders/#{order&.id}/cancel", "PATCH", order ? "発注 #{order.order_no}" : nil],
        ["orders", "export", "/orders/export", "GET", nil],
        ["order_approval_requests", "approve", "/order_approval_requests/1/approve", "PATCH", order ? "発注 #{order.order_no}" : nil],
        ["order_approval_requests", "reject", "/order_approval_requests/1/reject", "PATCH", order ? "発注 #{order.order_no}" : nil],
        ["customers", "create", "/customers", "POST", nil],
        ["customers", "update", "/customers/#{customer1&.id}", "PATCH", customer1 ? "センター #{customer1.center_name} (#{customer1.center_code})" : nil],
        ["customers", "destroy", "/customers/#{customer2&.id}", "PATCH", customer2 ? "センター #{customer2.center_name} (#{customer2.center_code})" : nil],
        ["customers", "download_invoice", "/customers/#{customer1&.id}/download_invoice", "GET", customer1 ? "センター #{customer1.center_name} (#{customer1.center_code})" : nil],
        ["customers", "import", "/customers/import", "POST", nil],
        ["items", "create", "/items", "POST", nil],
        ["items", "update", "/items/#{item&.id}", "PATCH", item ? "商品 #{item.item_code} (#{item.name})" : nil],
        ["items", "destroy", "/items/#{item&.id}", "PATCH", item ? "商品 #{item.item_code} (#{item.name})" : nil],
        ["items", "import", "/items/import", "POST", nil],
        ["manufacturers", "create", "/manufacturers", "POST", nil],
        ["manufacturers", "update", "/manufacturers/#{manufacturer&.id}", "PATCH", manufacturer ? "メーカー #{manufacturer.name} (#{manufacturer.code})" : nil],
        ["manufacturers", "destroy", "/manufacturers/#{manufacturer&.id}", "DELETE", manufacturer ? "メーカー #{manufacturer.name} (#{manufacturer.code})" : nil],
        ["shipping_requests", "register_shipment", "/shipping_requests/register_shipment", "POST", nil],
        ["admin/companies", "create", "/admin/companies", "POST", nil],
        ["admin/companies", "update", "/admin/companies/#{company&.id}", "PATCH", company ? "会社 #{company.name}" : nil],
        ["admin/company_payments", "create", "/admin/company_payments", "POST", nil],
        ["admin/company_payments", "update", "/admin/company_payments/1", "PATCH", company ? "入金 #{company.name} 2026年1月" : nil],
        ["admin/approval_requests", "approve", "/admin/approval_requests/1/approve", "PATCH", profile ? "メンバー #{profile.name} (#{profile.user&.email})" : nil],
        ["admin/approval_requests", "reject", "/admin/approval_requests/1/reject", "PATCH", profile ? "メンバー #{profile.name} (#{profile.user&.email})" : nil],
        ["admin/user_profiles", "update", "/admin/user_profiles/#{profile&.id}", "PATCH", profile ? "ユーザー #{profile.name} (#{profile.user&.email})" : nil],
        ["admin/user_profiles", "change_role", "/admin/user_profiles/#{profile&.id}/change_role", "PATCH", profile ? "ユーザー #{profile.name} (#{profile.user&.email})" : nil],
        ["admin/issuer_settings", "update", "/admin/issuer_setting", "PATCH", "発行元設定"],
        ["admin/access_logs", "index", "/admin/access_logs", "GET", nil],
      ]

      created = 0
      entries.each_with_index do |(ctrl, action, path, method, target), i|
        user = (i % 4 == 0) && company_admin ? company_admin : admin_user
        AccessLog.create!(
          user_id: user.id,
          user_name: user.user_profile&.name || "（未ログイン）",
          user_email: user.email,
          company_id: user.company_id || company.id,
          controller_path: ctrl,
          action_name: action,
          request_path: path,
          request_method: method,
          ip_address: "127.0.0.1",
          user_agent: "Mozilla/5.0 (Rails seed)",
          target_summary: AccessLog.column_names.include?("target_summary") ? target : nil,
          created_at: base_time + i.hours
        )
        created += 1
      end
      puts "  Created #{created} access log entries"
    end
  rescue => e
    puts "  ERROR creating access logs: #{e.message}"
    puts e.backtrace.first(3).join("\n")
  end
end

puts ""
puts "Seed completed!"
puts ""
puts "Summary:"
puts "  Companies: #{Company.count}"
puts "  Manufacturers: #{ActiveRecord::Base.connection.table_exists?('manufacturers') ? Manufacturer.count : 0}"
puts "  Customers (Centers): #{Customer.count} (Billing: #{Customer.billing_centers.count}, Receiving: #{Customer.receiving_centers.count})"
puts "  Items: #{Item.count}"
puts "  Orders: #{Order.count} (in January #{SEED_YEAR}: #{Order.where(order_date: SEED_JANUARY).count})"
puts "  発送依頼対象（confirmed/shipped）: #{Order.where(shipping_status: %i[confirmed shipped]).count}"
puts "  Users: #{User.count}"
puts "  Access logs: #{AccessLog.count}" if ActiveRecord::Base.connection.table_exists?("access_logs")
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
if platform_manufacturers.any?
  puts "【メーカーアカウント（プラットフォーム共通）】"
  platform_manufacturers.each do |m|
    safe_code = m.code.downcase.gsub(/[^a-z0-9]/, "-")
    puts "  メーカー（#{m.name}） ID: maker-#{safe_code}@platform.example.com  パスワード: #{SEED_PASSWORD}"
  end
  puts "※1メーカーで複数会社の発送依頼を参照できます。"
end
puts "※メーカーアカウントは user_profiles に manufacturer_id カラムがある場合のみ作成されます（bin/rails db:migrate 実行後、RESET=1 で再 seed）" unless UserProfile.column_names.include?("manufacturer_id")
puts "=================================================================================="
