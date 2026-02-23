# frozen_string_literal: true

# プラットフォーム共通マスタ。1メーカーが複数会社の商品に紐づき、複数会社の発送依頼を見る。
# domains を設定すると、そのドメインのメールアドレスで登録したユーザーがメーカー用户として紐づく（クローズドリサイクル）。
class Manufacturer < ApplicationRecord
  include Auditable

  # Associations
  has_many :items, dependent: :nullify
  has_many :user_profiles, dependent: :nullify

  # Validations
  validates :code, presence: true, length: { maximum: 50 }, uniqueness: true
  validates :name, presence: true, length: { maximum: 255 }
  validates :payment_terms, length: { maximum: 255 }, allow_blank: true
  validate :domains_must_be_array_of_valid_domains

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :ordered_by_code, -> { order(:code) }

  # メールアドレスのドメインがこのメーカーの domains に含まれるか
  def self.find_by_email_domain(email)
    domain = email.to_s.split("@").last&.downcase
    return nil if domain.blank?

    active.find_each do |m|
      next unless m.domains.is_a?(Array) && m.domains.any?
      return m if m.domains.any? { |d| d.to_s.downcase == domain }
    end
    nil
  end

  def display_name
    "#{code}: #{name}"
  end

  private

  def domains_must_be_array_of_valid_domains
    return unless domains.is_a?(Array) && domains.any?
    domain_regex = /\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}\z/i
    domains.each do |d|
      unless d.is_a?(String) && d.match?(domain_regex)
        errors.add(:domains, "に無効な形式が含まれています: #{d}")
      end
    end
  end
end
