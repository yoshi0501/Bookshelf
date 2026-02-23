# frozen_string_literal: true

# 会社ごとの請求期間（年・月）に対する入金管理。
# paid_at が nil = 未入金。入金日を登録すると入金済みになる。
class CompanyPayment < ApplicationRecord
  include Auditable

  belongs_to :company

  validates :year, presence: true, numericality: { only_integer: true, in: 2000..2100 }
  validates :month, presence: true, numericality: { only_integer: true, in: 1..12 }
  validates :company_id, uniqueness: { scope: [:year, :month], message: "の同じ年月が既に登録されています" }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :unpaid, -> { where(paid_at: nil) }
  scope :paid, -> { where.not(paid_at: nil) }
  scope :overdue, -> { unpaid.where("due_date IS NOT NULL AND due_date < ?", Date.current) }
  scope :by_period_desc, -> { order(year: :desc, month: :desc) }

  # 表示用：amount が未設定なら当該会社・年月の発注合計を返す（未設定時は 0）
  def display_amount
    amount.presence || computed_order_total || 0
  end

  def paid?
    paid_at.present?
  end

  def overdue?
    !paid? && due_date.present? && due_date < Date.current
  end

  def period_label
    "#{year}年#{month}月"
  end

  private

  def computed_order_total
    return nil unless company_id.present?
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    company.orders.where(order_date: start_date..end_date).where.not(shipping_status: :cancelled).sum(:total_amount)
  end
end
