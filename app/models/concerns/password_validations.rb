# frozen_string_literal: true

module PasswordValidations
  extend ActiveSupport::Concern

  # ユーザーID（メールアドレス）と同一・推測されやすいパスワードを拒否するため
  COMMON_PASSWORDS = %w[
    aaa aaa12345 1234 12345 123456 1234567 12345678 123456789
    password password1 password12 password123 passw0rd pass1234
    qwerty qwerty123 admin admin123 administrator root guest
    letmein welcome welcome1 monkey dragon master login
    abc123 abcdef 111111 000000 654321 p@ssw0rd
    test test1234 sample changeme default
  ].freeze

  included do
    validate :password_not_same_as_email, if: :password_present?
    validate :password_not_common, if: :password_present?
  end

  private

  def password_present?
    password.present?
  end

  def password_not_same_as_email
    return unless email.present?

    errors.add(:password, :same_as_email) if password.casecmp(email).zero?
  end

  def password_not_common
    return if password.blank?

    if PasswordValidations::COMMON_PASSWORDS.any? { |common| password.casecmp(common).zero? }
      errors.add(:password, :too_common)
    end
  end
end
