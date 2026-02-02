# frozen_string_literal: true

module AuthHelpers
  # テスト用のログインヘルパー
  # 使用例: login_as_admin または login_as(user)
  
  def login_as(user_or_email, password: "password123456")
    user = if user_or_email.is_a?(String)
      User.find_by(email: user_or_email) || create_test_user(user_or_email, password: password)
    else
      user_or_email
    end
    
    sign_in(user)
    user
  end

  # 内部管理者としてログイン
  def login_as_internal_admin
    company = Company.find_or_create_by!(code: "TEST") do |c|
      c.name = "Test Company"
      c.domains = ["system.local"]
      c.order_prefix = "TST"
      c.order_seq = 0
      c.is_active = true
    end
    
    user = User.find_or_initialize_by(email: "admin@system.local")
    if user.new_record?
      user.password = "password123456"
      user.password_confirmation = "password123456"
      user.confirmed_at = Time.current
      user.save!
    end
    
    user.user_profile&.destroy
    user.create_user_profile!(
      company: company,
      name: "System Administrator",
      role: :internal_admin,
      member_status: :active
    )
    
    sign_in(user)
    user
  end

  # 会社管理者としてログイン
  def login_as_company_admin(company: nil)
    company ||= Company.find_or_create_by!(code: "ACME") do |c|
      c.name = "Acme Corporation"
      c.domains = ["acme.com"]
      c.order_prefix = "ACM"
      c.order_seq = 0
      c.is_active = true
    end
    
    user = User.find_or_initialize_by(email: "admin@acme.com")
    if user.new_record?
      user.password = "password123456"
      user.password_confirmation = "password123456"
      user.confirmed_at = Time.current
      user.save!
    end
    
    user.user_profile&.destroy
    user.create_user_profile!(
      company: company,
      name: "Acme Admin",
      role: :company_admin,
      member_status: :active
    )
    
    sign_in(user)
    user
  end

  # 一般ユーザーとしてログイン
  def login_as_normal_user(company: nil)
    company ||= Company.find_or_create_by!(code: "ACME") do |c|
      c.name = "Acme Corporation"
      c.domains = ["acme.com"]
      c.order_prefix = "ACM"
      c.order_seq = 0
      c.is_active = true
    end
    
    user = User.find_or_initialize_by(email: "user@acme.com")
    if user.new_record?
      user.password = "password123456"
      user.password_confirmation = "password123456"
      user.confirmed_at = Time.current
      user.save!
    end
    
    user.user_profile&.destroy
    user.create_user_profile!(
      company: company,
      name: "Acme User",
      role: :normal,
      member_status: :active
    )
    
    sign_in(user)
    user
  end

  private

  def create_test_user(email, password: "password123456")
    company = Company.find_or_create_by!(code: "TEST") do |c|
      c.name = "Test Company"
      c.domains = [email.split("@").last]
      c.order_prefix = "TST"
      c.order_seq = 0
      c.is_active = true
    end
    
    user = User.create!(
      email: email,
      password: password,
      password_confirmation: password,
      confirmed_at: Time.current
    )
    
    user.create_user_profile!(
      company: company,
      name: email.split("@").first,
      role: :normal,
      member_status: :active
    )
    
    user
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
  config.include AuthHelpers, type: :controller
  config.include AuthHelpers, type: :system if defined?(Capybara)
end
