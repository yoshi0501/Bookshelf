# frozen_string_literal: true

# B2B Multi-tenant Order System - Seed Data
# Run with: rails db:seed

puts "Creating companies..."

company_a = Company.create!(
  name: "Acme Corporation",
  code: "ACME",
  domains: ["acme.com", "acme.co.jp"],
  order_prefix: "ACM",
  order_seq: 0,
  is_active: true
)

company_b = Company.create!(
  name: "Beta Industries",
  code: "BETA",
  domains: ["beta-ind.com"],
  order_prefix: "BET",
  order_seq: 0,
  is_active: true
)

puts "Creating users..."

# Internal Admin
internal_admin = User.new(
  email: "admin@system.local",
  password: "password123456",
  password_confirmation: "password123456",
  confirmed_at: Time.current
)
internal_admin.save!
internal_admin.user_profile&.destroy
UserProfile.create!(
  user: internal_admin,
  company: company_a,
  name: "System Administrator",
  role: :internal_admin,
  member_status: :active
)

# Company A Admin
company_a_admin = User.new(
  email: "admin@acme.com",
  password: "password123456",
  password_confirmation: "password123456",
  confirmed_at: Time.current
)
company_a_admin.save!
company_a_admin.user_profile&.destroy
UserProfile.create!(
  user: company_a_admin,
  company: company_a,
  name: "Acme Admin",
  role: :company_admin,
  member_status: :active
)

# Company A Normal User
company_a_user = User.new(
  email: "user@acme.com",
  password: "password123456",
  password_confirmation: "password123456",
  confirmed_at: Time.current
)
company_a_user.save!
company_a_user.user_profile&.destroy
UserProfile.create!(
  user: company_a_user,
  company: company_a,
  name: "Acme User",
  role: :normal,
  member_status: :active
)

# Company B Admin
company_b_admin = User.new(
  email: "admin@beta-ind.com",
  password: "password123456",
  password_confirmation: "password123456",
  confirmed_at: Time.current
)
company_b_admin.save!
company_b_admin.user_profile&.destroy
UserProfile.create!(
  user: company_b_admin,
  company: company_b,
  name: "Beta Admin",
  role: :company_admin,
  member_status: :active
)

puts "Creating customers..."

# Company A Customers
3.times do |i|
  Customer.create!(
    company: company_a,
    center_code: "AC#{(i + 1).to_s.rjust(3, '0')}",
    center_name: "Acme Center #{i + 1}",
    postal_code: "100-000#{i + 1}",
    prefecture: "Tokyo",
    city: "Chiyoda",
    address1: "#{i + 1}-1-1 Marunouchi",
    is_active: true
  )
end

# Company B Customers
2.times do |i|
  Customer.create!(
    company: company_b,
    center_code: "BC#{(i + 1).to_s.rjust(3, '0')}",
    center_name: "Beta Center #{i + 1}",
    postal_code: "530-000#{i + 1}",
    prefecture: "Osaka",
    city: "Osaka",
    address1: "#{i + 1}-2-3 Umeda",
    is_active: true
  )
end

puts "Creating items..."

# Company A Items
[
  { code: "A001", name: "Widget A", price: 1000, co2: 0.5 },
  { code: "A002", name: "Widget B", price: 2500, co2: 0.8 },
  { code: "A003", name: "Widget C", price: 5000, co2: 1.2 },
  { code: "A004", name: "Premium Widget", price: 10000, co2: 2.0 }
].each do |item|
  Item.create!(
    company: company_a,
    item_code: item[:code],
    name: item[:name],
    unit_price: item[:price],
    co2_per_unit: item[:co2],
    is_active: true
  )
end

# Company B Items
[
  { code: "B001", name: "Gadget X", price: 1500, co2: 0.6 },
  { code: "B002", name: "Gadget Y", price: 3000, co2: 1.0 },
  { code: "B003", name: "Gadget Z", price: 7500, co2: 1.5 }
].each do |item|
  Item.create!(
    company: company_b,
    item_code: item[:code],
    name: item[:name],
    unit_price: item[:price],
    co2_per_unit: item[:co2],
    is_active: true
  )
end

puts "Creating sample orders..."

# Company A Orders
company_a_customers = Customer.where(company: company_a)
company_a_items = Item.where(company: company_a)

3.times do |i|
  customer = company_a_customers.sample
  order = Order.create!(
    company: company_a,
    customer: customer,
    ordered_by_user: company_a_user,
    order_date: Date.current - i.days,
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

puts "Seed completed!"
puts ""
puts "Test Accounts:"
puts "  Internal Admin: admin@system.local / password123456"
puts "  Company A Admin: admin@acme.com / password123456"
puts "  Company A User: user@acme.com / password123456"
puts "  Company B Admin: admin@beta-ind.com / password123456"
