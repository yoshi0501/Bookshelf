# frozen_string_literal: true

# センター（請求先センター・受注センター）を表すモデル。
# 会社（Company）に属し、請求先として使うか・受注拠点として使うかで is_billing_center で区別する。
class Customer < ApplicationRecord
  include MultiTenant
  include Auditable

  # Associations
  belongs_to :billing_center, class_name: "Customer", foreign_key: :billing_center_id, optional: true
  has_many :customers, class_name: "Customer", foreign_key: :billing_center_id, dependent: :restrict_with_error
  has_many :orders, dependent: :restrict_with_error

  # Validations
  validates :center_code, presence: true, length: { maximum: 50 },
            uniqueness: { scope: :company_id }
  validates :center_name, presence: true, length: { maximum: 255 }
  validates :postal_code, length: { maximum: 10 }, allow_blank: true,
            format: { with: /\A\d{3}-?\d{4}\z/, message: "must be valid format (e.g., 123-4567)", allow_blank: true }
  validates :prefecture, length: { maximum: 50 }
  validates :city, length: { maximum: 100 }
  validates :address1, length: { maximum: 255 }
  validates :address2, length: { maximum: 255 }
  validate :billing_center_must_be_same_company
  validate :billing_center_must_be_billing_center
  validate :cannot_be_own_billing_center
  validate :receiving_center_must_have_billing_center

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_code, ->(code) { where(center_code: code) }
  scope :billing_centers, -> { where(is_billing_center: true) }
  scope :receiving_centers, -> { where(is_billing_center: false) }

  # Instance methods
  def is_billing_center?
    is_billing_center == true || is_billing_center == '1' || is_billing_center == 1
  end

  def full_address
    [postal_code, prefecture, city, address1, address2].compact_blank.join(" ")
  end

  def display_name
    "#{center_code}: #{center_name}"
  end

  # Create shipping address snapshot hash
  def to_shipping_snapshot
    {
      ship_postal_code: postal_code,
      ship_prefecture: prefecture,
      ship_city: city,
      ship_address1: address1,
      ship_address2: address2,
      ship_center_name: center_name
    }
  end

  private

  def billing_center_must_be_same_company
    return unless billing_center.present? && company_id.present?

    if billing_center.company_id != company_id
      errors.add(:billing_center_id, "must belong to the same company")
    end
  end

  def billing_center_must_be_billing_center
    return unless billing_center.present?

    unless billing_center.is_billing_center?
      errors.add(:billing_center_id, "must be a billing center")
    end
  end

  def cannot_be_own_billing_center
    return unless billing_center_id.present? && id.present?

    if billing_center_id == id
      errors.add(:billing_center_id, "cannot be itself")
    end
  end

  def receiving_center_must_have_billing_center
    # 受注センター（is_billing_center: false）の場合は、請求先センターが必須
    return if is_billing_center?

    if billing_center_id.blank?
      errors.add(:billing_center_id, "must be present for receiving centers")
    end
  end
end
