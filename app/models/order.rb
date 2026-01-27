# frozen_string_literal: true

class Order < ApplicationRecord
  include MultiTenant
  include Auditable

  # Enums
  enum :shipping_status, {
    draft: 0,
    confirmed: 1,
    shipped: 2,
    delivered: 3,
    cancelled: 4
  }, prefix: true

  # Associations
  belongs_to :ordered_by_user, class_name: "User"
  belongs_to :customer
  has_many :order_lines, dependent: :destroy
  has_many :items, through: :order_lines
  has_many :integration_logs, dependent: :destroy

  # Validations
  validates :order_no, presence: true, uniqueness: { scope: :company_id }
  validates :order_date, presence: true
  validates :ordered_by_user_id, presence: true
  validates :customer_id, presence: true
  validates :shipping_status, presence: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :co2_total, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :customer_belongs_to_same_company

  # Scopes
  scope :by_date_range, ->(start_date, end_date) {
    where(order_date: start_date..end_date) if start_date.present? && end_date.present?
  }
  scope :by_status, ->(status) { where(shipping_status: status) if status.present? }
  scope :search_by_order_no, ->(query) {
    where("order_no ILIKE ?", "%#{sanitize_sql_like(query)}%") if query.present?
  }
  scope :recent, -> { order(order_date: :desc, created_at: :desc) }

  # Callbacks
  before_validation :set_order_no, on: :create
  before_validation :snapshot_customer_address, on: :create
  after_save :recalculate_totals, if: :should_recalculate?

  # Nested attributes
  accepts_nested_attributes_for :order_lines, allow_destroy: true,
    reject_if: proc { |attrs| attrs["item_id"].blank? || attrs["quantity"].blank? }

  # Class methods
  def self.create_with_lines!(attributes, line_attributes, user)
    transaction do
      order = new(attributes)
      order.ordered_by_user = user
      order.company = user.current_company

      order.save!

      line_attributes.each do |line_attrs|
        item = Item.find_for_company!(line_attrs[:item_id], order.company)
        order.order_lines.create!(
          company: order.company,
          item: item,
          quantity: line_attrs[:quantity],
          unit_price_snapshot: item.unit_price,
          amount: item.unit_price * line_attrs[:quantity].to_i,
          co2_amount: (item.co2_per_unit || 0) * line_attrs[:quantity].to_i
        )
      end

      order.recalculate_totals!
      order
    end
  end

  # Instance methods
  def recalculate_totals!
    update!(
      total_amount: order_lines.sum(:amount),
      co2_total: order_lines.sum(:co2_amount)
    )
  end

  def can_be_edited?
    shipping_status_draft? || shipping_status_confirmed?
  end

  def can_be_cancelled?
    !shipping_status_delivered? && !shipping_status_cancelled?
  end

  def ship!(tracking_no, ship_date = Date.current)
    update!(
      shipping_status: :shipped,
      tracking_no: tracking_no,
      ship_date: ship_date
    )
  end

  def deliver!(delivered_date = Date.current)
    update!(
      shipping_status: :delivered,
      delivered_date: delivered_date
    )
  end

  def cancel!
    update!(shipping_status: :cancelled)
  end

  def full_shipping_address
    [ship_postal_code, ship_prefecture, ship_city, ship_address1, ship_address2]
      .compact_blank.join(" ")
  end

  private

  def set_order_no
    return if order_no.present?
    return unless company

    self.order_no = company.generate_next_order_no!
  end

  def snapshot_customer_address
    return unless customer
    return if ship_center_name.present?

    assign_attributes(customer.to_shipping_snapshot)
  end

  def customer_belongs_to_same_company
    return unless customer && company

    unless customer.company_id == company_id
      errors.add(:customer, "must belong to the same company")
    end
  end

  def should_recalculate?
    false # Manual recalculation only
  end
end
