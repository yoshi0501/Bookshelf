# frozen_string_literal: true

# Test Environment Seed Data
# Run with: RAILS_ENV=test rails db:seed:test
# Or: rails runner db/seeds_test.rb

puts "Creating test companies..."

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

puts "Creating test users..."

# Internal Admin
internal_admin = User.find_or_initialize_by(email: "admin@system.local")
if internal_admin.new_record?
  internal_admin.password = "Password123456"
  internal_admin.password_confirmation = "Password123456"
  internal_admin.confirmed_at = Time.current
  internal_admin.save!
end
internal_admin.user_profile&.destroy
internal_admin.create_user_profile!(
  company: company_a,
  name: "System Administrator",
  role: :internal_admin,
  member_status: :active
)

# Company A Admin
company_a_admin = User.find_or_initialize_by(email: "admin@acme.com")
if company_a_admin.new_record?
  company_a_admin.password = "Password123456"
  company_a_admin.password_confirmation = "Password123456"
  company_a_admin.confirmed_at = Time.current
  company_a_admin.save!
end
company_a_admin.user_profile&.destroy
company_a_admin.create_user_profile!(
  company: company_a,
  name: "Acme Admin",
  role: :company_admin,
  member_status: :active
)

# Company A Normal User
company_a_user = User.find_or_initialize_by(email: "user@acme.com")
if company_a_user.new_record?
  company_a_user.password = "Password123456"
  company_a_user.password_confirmation = "Password123456"
  company_a_user.confirmed_at = Time.current
  company_a_user.save!
end
company_a_user.user_profile&.destroy
company_a_user.create_user_profile!(
  company: company_a,
  name: "Acme User",
  role: :normal,
  member_status: :active
)

# Company B Admin
company_b_admin = User.find_or_initialize_by(email: "admin@beta-ind.com")
if company_b_admin.new_record?
  company_b_admin.password = "Password123456"
  company_b_admin.password_confirmation = "Password123456"
  company_b_admin.confirmed_at = Time.current
  company_b_admin.save!
end
company_b_admin.user_profile&.destroy
company_b_admin.create_user_profile!(
  company: company_b,
  name: "Beta Admin",
  role: :company_admin,
  member_status: :active
)

puts "Test seed completed!"
puts ""
puts "Test Accounts (password: Password123456):"
puts "  Internal Admin: admin@system.local"
puts "  Company A Admin: admin@acme.com"
puts "  Company A User: user@acme.com"
puts "  Company B Admin: admin@beta-ind.com"
