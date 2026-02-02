# frozen_string_literal: true

class Customer < ApplicationRecord
  include MultiTenant
  include Auditable

  # Associations
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

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_code, ->(code) { where(center_code: code) }

  # Instance methods
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
end
