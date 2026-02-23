# frozen_string_literal: true

class OrderLine < ApplicationRecord
  include MultiTenant
  include Auditable

  # Associations
  belongs_to :order
  belongs_to :item

  # Validations
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_snapshot, presence: true,
            numericality: { greater_than_or_equal_to: 0 }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :co2_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :item_belongs_to_same_company

  # Callbacks
  before_validation :calculate_amounts, if: :should_calculate?

  # Scopes
  scope :ordered_by_item, -> { includes(:item).order("items.item_code") }

  # Instance methods
  def calculate_amounts
    return unless item && quantity

    self.unit_price_snapshot ||= item.unit_price
    self.cost_price_snapshot = item.cost_price.to_d if item.respond_to?(:cost_price)
    self.shipping_cost_snapshot = item.shipping_cost.to_d if item.respond_to?(:shipping_cost)
    self.amount = unit_price_snapshot * quantity
    self.co2_amount = (item.co2_per_unit || 0) * quantity
  end

  def item_name
    item&.name
  end

  def item_code
    item&.item_code
  end

  private

  def should_calculate?
    quantity_changed? || item_id_changed? || new_record?
  end

  def item_belongs_to_same_company
    return unless item && company

    unless item.company_id == company_id
      errors.add(:item, "must belong to the same company")
    end
  end
end
