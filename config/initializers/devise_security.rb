# frozen_string_literal: true

# Devise Security Extension configuration
Devise.setup do |config|
  # Password expirable - 90 days (3 months)
  config.expire_password_after = 90.days

  # Deny old passwords on change
  config.deny_old_passwords = 5 # Remember last 5 passwords

  # Password complexity: 英数字混在（8桁以上且つ英数字混在の要件）
  config.password_complexity = {
    digit: 1,
    lower: 1,
    upper: 1
  }
end
