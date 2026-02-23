# frozen_string_literal: true

class Item < ApplicationRecord
  include MultiTenant
  include Auditable

  # Associations
  belongs_to :manufacturer, optional: true
  has_one_attached :image
  has_many :order_lines, dependent: :restrict_with_error
  has_many :item_companies, dependent: :destroy
  has_many :visible_companies, through: :item_companies, source: :company

  # Validations
  validates :item_code, presence: true, length: { maximum: 50 },
            uniqueness: { scope: :company_id }
  validates :name, presence: true, length: { maximum: 255 }
  validates :unit_price, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 }
  validates :co2_per_unit, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cost_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :shipping_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_code, ->(code) { where(item_code: code) }
  scope :ordered_by_code, -> { order(:item_code) }

  # Instance methods
  def display_name
    "#{item_code}: #{name}"
  end

  def formatted_price
    ActionController::Base.helpers.number_to_currency(unit_price, unit: "¥", precision: 0)
  end

  private
end
