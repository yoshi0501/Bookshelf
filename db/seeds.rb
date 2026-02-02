# frozen_string_literal: true

# B2B Multi-tenant Order System - Seed Data
# Run with: rails db:seed

puts "Creating companies..."

company_a = Company.find_or_create_by!(code: "ACME") do |c|
  c.name = "Acme Corporation"
  c.domains = ["acme.com", "acme.co.jp"]
  c.order_prefix = "ACM"
  c.order_seq = 0
  c.is_active = true
end

company_b = Company.find_or_create_by!(code: "BETA") do |c|
  c.name = "Beta Industries"
  c.domains = ["beta-ind.com"]
  c.order_prefix = "BET"
  c.order_seq = 0
  c.is_active = true
end

puts "Creating users..."

# Internal Admin
internal_admin = User.find_or_initialize_by(email: "admin@system.local")
internal_admin.password = "password123456"
internal_admin.password_confirmation = "password123456"
internal_admin.confirmed_at = Time.current
internal_admin.save!
internal_admin.user_profile&.destroy
internal_admin.create_user_profile!(
  company: nil, # Internal Adminは会社に紐づかない
  name: "System Administrator",
  role: :internal_admin,
  member_status: :active
)

# Company A Admin
company_a_admin = User.find_or_initialize_by(email: "admin@acme.com")
company_a_admin.password = "password123456"
company_a_admin.password_confirmation = "password123456"
company_a_admin.confirmed_at = Time.current
company_a_admin.save!
company_a_admin.user_profile&.destroy
company_a_admin.create_user_profile!(
  company: company_a,
  name: "Acme Admin",
  role: :company_admin,
  member_status: :active
)

# Company A Normal User
company_a_user = User.find_or_initialize_by(email: "user@acme.com")
company_a_user.password = "password123456"
company_a_user.password_confirmation = "password123456"
company_a_user.confirmed_at = Time.current
company_a_user.save!
company_a_user.user_profile&.destroy
company_a_user.create_user_profile!(
  company: company_a,
  name: "Acme User",
  role: :normal,
  member_status: :active
)

# Company B Admin
company_b_admin = User.find_or_initialize_by(email: "admin@beta-ind.com")
company_b_admin.password = "password123456"
company_b_admin.password_confirmation = "password123456"
company_b_admin.confirmed_at = Time.current
company_b_admin.save!
company_b_admin.user_profile&.destroy
company_b_admin.create_user_profile!(
  company: company_b,
  name: "Beta Admin",
  role: :company_admin,
  member_status: :active
)

puts "Creating customers..."

# Company A Customers
3.times do |i|
  center_code = "AC#{(i + 1).to_s.rjust(3, '0')}"
  Customer.find_or_create_by!(company: company_a, center_code: center_code) do |c|
    c.center_name = "Acme Center #{i + 1}"
    c.postal_code = "100-000#{i + 1}"
    c.prefecture = "Tokyo"
    c.city = "Chiyoda"
    c.address1 = "#{i + 1}-1-1 Marunouchi"
    c.is_active = true
  end
end

# Company B Customers
2.times do |i|
  center_code = "BC#{(i + 1).to_s.rjust(3, '0')}"
  Customer.find_or_create_by!(company: company_b, center_code: center_code) do |c|
    c.center_name = "Beta Center #{i + 1}"
    c.postal_code = "530-000#{i + 1}"
    c.prefecture = "Osaka"
    c.city = "Osaka"
    c.address1 = "#{i + 1}-2-3 Umeda"
    c.is_active = true
  end
end

puts "Creating items..."

# Company A Items
[
  { code: "A001", name: "Widget A", price: 1000, co2: 0.5 },
  { code: "A002", name: "Widget B", price: 2500, co2: 0.8 },
  { code: "A003", name: "Widget C", price: 5000, co2: 1.2 },
  { code: "A004", name: "Premium Widget", price: 10000, co2: 2.0 }
].each do |item|
  Item.find_or_create_by!(company: company_a, item_code: item[:code]) do |i|
    i.name = item[:name]
    i.unit_price = item[:price]
    i.co2_per_unit = item[:co2]
    i.is_active = true
  end
end

# Company B Items
[
  { code: "B001", name: "Gadget X", price: 1500, co2: 0.6 },
  { code: "B002", name: "Gadget Y", price: 3000, co2: 1.0 },
  { code: "B003", name: "Gadget Z", price: 7500, co2: 1.5 }
].each do |item|
  Item.find_or_create_by!(company: company_b, item_code: item[:code]) do |i|
    i.name = item[:name]
    i.unit_price = item[:price]
    i.co2_per_unit = item[:co2]
    i.is_active = true
  end
end

puts "Creating sample orders..."

# Company A Orders (only create if they don't exist)
company_a_customers = Customer.where(company: company_a)
company_a_items = Item.where(company: company_a)

if company_a_customers.any? && company_a_items.any? && Order.where(company: company_a).count < 3
  3.times do |i|
    customer = company_a_customers.sample
    order_date = Date.current - i.days
    
    # Skip if order already exists for this date
    next if Order.exists?(company: company_a, customer: customer, order_date: order_date)
    
    order = Order.create!(
      company: company_a,
      customer: customer,
      ordered_by_user: company_a_user,
      order_date: order_date,
      shipping_status: %i[draft confirmed shipped][i % 3],
      ship_postal_code: customer.postal_code,
      ship_prefecture: customer.prefecture,
      ship_city: customer.city,
      ship_address1: customer.address1,
      ship_center_name: customer.center_name
    )

    rand(1..3).times do
      item = company_a_items.sample
      qty = rand(1..5)
      OrderLine.create!(
        company: company_a,
        order: order,
        item: item,
        quantity: qty,
        unit_price_snapshot: item.unit_price,
        amount: item.unit_price * qty,
        co2_amount: (item.co2_per_unit || 0) * qty
      )
    end

    order.recalculate_totals!
  end
end

puts "Seed completed!"
puts ""
puts "Test Accounts:"
puts "  Internal Admin: admin@system.local / password123456"
puts "  Company A Admin: admin@acme.com / password123456"
puts "  Company A User: user@acme.com / password123456"
puts "  Company B Admin: admin@beta-ind.com / password123456"
