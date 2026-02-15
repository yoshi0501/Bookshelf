# frozen_string_literal: true

class Company < ApplicationRecord
  include Auditable

  # Associations
  has_many :user_profiles, dependent: :restrict_with_error
  has_many :users, through: :user_profiles
  has_many :approval_requests, dependent: :restrict_with_error
  has_many :customers, dependent: :restrict_with_error
  has_many :items, dependent: :restrict_with_error
  has_many :item_companies, dependent: :destroy
  has_many :visible_items, through: :item_companies, source: :item
  has_many :orders, dependent: :restrict_with_error
  has_many :order_lines, dependent: :restrict_with_error
  has_many :integration_logs, dependent: :destroy
  has_many :company_payments, dependent: :destroy
  has_many :access_logs, dependent: :nullify

  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :code, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :payment_terms, length: { maximum: 255 }, allow_blank: true
  validates :order_prefix, presence: true, length: { maximum: 10 },
            format: { with: /\A[A-Z0-9]+\z/, message: "must be uppercase alphanumeric" }
  validates :order_seq, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :domains, presence: true
  validate :domains_must_be_array_of_valid_domains

  # Scopes
  scope :active, -> { where(is_active: true) }

  # Class methods
  def self.find_by_email_domain(email)
    domain = email.to_s.split("@").last&.downcase
    return nil if domain.blank?

    active.find_each do |company|
      return company if company.domains.any? { |d| d.downcase == domain }
    end
    nil
  end

  # 請求書用：住所を1行で返す
  def full_address
    [postal_code, prefecture, city, address1, address2].compact_blank.join(" ")
  end

  # Instance methods
  def generate_next_order_no!
    # Use row-level lock to prevent race condition
    with_lock do
      next_seq = order_seq + 1
      update_column(:order_seq, next_seq)
      "#{order_prefix}-#{next_seq.to_s.rjust(7, '0')}"
    end
  end

  private

  def domains_must_be_array_of_valid_domains
    unless domains.is_a?(Array)
      errors.add(:domains, "must be an array")
      return
    end

    if domains.empty?
      errors.add(:domains, "must have at least one domain")
      return
    end

    domain_regex = /\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}\z/i
    domains.each do |domain|
      unless domain.is_a?(String) && domain.match?(domain_regex)
        errors.add(:domains, "contains invalid domain: #{domain}")
      end
    end
  end
end
