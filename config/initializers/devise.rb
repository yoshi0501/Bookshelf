# frozen_string_literal: true

require_relative "../../app/lib/devise_failure_app"

Devise.setup do |config|
  config.mailer_sender = "noreply@example.com"

  require "devise/orm/active_record"

  # Authentication
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]

  # Password
  config.stretches = Rails.env.test? ? 1 : 12
  config.password_length = 12..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  # Confirmable
  config.allow_unconfirmed_access_for = 2.days
  config.confirm_within = 3.days
  config.reconfirmable = true

  # Rememberable
  config.remember_for = 2.weeks
  config.extend_remember_period = false
  config.rememberable_options = {}

  # Recoverable
  config.reset_password_within = 6.hours
  config.reset_password_keys = [:email]

  # Lockable
  config.lock_strategy = :failed_attempts
  config.unlock_keys = [:email]
  config.unlock_strategy = :both
  config.maximum_attempts = 5
  config.unlock_in = 1.hour
  config.last_attempt_warning = true

  # Trackable (sign in count, timestamps, IP addresses)
  # Enabled via :trackable in User model

  # Timeout (session expiration)
  config.timeout_in = 30.minutes

  # Token expiration
  config.expire_all_remember_me_on_sign_out = true

  # Paranoid mode - don't reveal if email exists
  config.paranoid = true

  # Scoped views
  config.scoped_views = false

  # Navigation
  config.sign_out_via = :delete
  config.responder.error_status = :unprocessable_content
  config.responder.redirect_status = :see_other

  # Custom failure app for better error messages
  config.warden do |manager|
    manager.failure_app = DeviseFailureApp
  end
end
