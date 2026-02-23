# frozen_string_literal: true

class UserProfile < ApplicationRecord
  include Auditable

  # Enums
  enum :role, { normal: 0, approver: 1, company_admin: 2, internal_admin: 3 }, prefix: true
  enum :member_status, { pending: 0, active: 1, rejected: 2, unassigned: 3 }, prefix: true

  # Associations
  belongs_to :user
  belongs_to :company, optional: true
  belongs_to :manufacturer, optional: true
  belongs_to :supervisor, class_name: "UserProfile", optional: true
  has_many :subordinates, class_name: "UserProfile", foreign_key: "supervisor_id", dependent: :nullify
  has_many :approval_requests, dependent: :destroy

  # Validations
  validates :user_id, presence: true, uniqueness: true
  validates :name, presence: true, length: { maximum: 255 }
  validates :phone, length: { maximum: 50 }, allow_blank: true
  validates :payment_terms, length: { maximum: 255 }, allow_blank: true
  validates :role, presence: true
  validates :member_status, presence: true
  validates :company_id, presence: true, unless: :company_optional?
  validate :manufacturer_belongs_to_company_if_both_present
  validate :supervisor_must_be_same_company
  validate :cannot_be_own_supervisor

  # Scopes
  scope :for_company, ->(company) { where(company: company) }
  # 会社に所属するメンバー（メーカーはプラットフォーム共通のため別タブで表示）
  scope :for_company_including_manufacturers, ->(company) {
    return none unless company
    where(company_id: company.id)
  }
  scope :manufacturer_accounts, -> { where.not(manufacturer_id: nil) }
  scope :pending_approval, -> { where(member_status: :pending) }
  scope :active_members, -> { where(member_status: :active) }
  scope :admins_for_company, ->(company) { for_company(company).where(role: :company_admin) }

  # Instance methods
  def active?
    member_status_active?
  end

  def pending?
    member_status_pending?
  end

  def rejected?
    member_status_rejected?
  end

  def unassigned?
    member_status_unassigned?
  end

  def can_approve_members?
    role_company_admin? || role_internal_admin?
  end

  def can_access_admin_dashboard?
    role_company_admin? || role_internal_admin?
  end

  # Role convenience methods (without prefix)
  def normal?
    role_normal?
  end

  def company_admin?
    role_company_admin?
  end

  def internal_admin?
    role_internal_admin?
  end

  def approver?
    role_approver?
  end

  def can_approve_orders?
    role_approver? || role_company_admin? || role_internal_admin?
  end

  # メーカーとしてログインするユーザー（発送依頼のみ自社分を表示）
  def manufacturer_user?
    respond_to?(:manufacturer_id) && manufacturer_id.present?
  end

  def supervisor_user
    supervisor&.user
  end

  def has_supervisor?
    supervisor.present?
  end

  private

  def company_optional?
    unassigned? || role_internal_admin? || (respond_to?(:manufacturer_id) && manufacturer_id.present?)
  end

  def manufacturer_belongs_to_company_if_both_present
    return unless respond_to?(:manufacturer_id) && manufacturer_id.present? && company_id.present?
    return unless manufacturer&.respond_to?(:company_id) && manufacturer.company_id.present?

    unless manufacturer.company_id == company_id
      errors.add(:manufacturer_id, "must belong to the selected company")
    end
  end

  def supervisor_must_be_same_company
    return unless supervisor_id.present? && company_id.present?

    unless supervisor&.company_id == company_id
      errors.add(:supervisor_id, "must belong to the same company")
    end
  end

  def cannot_be_own_supervisor
    return unless supervisor_id.present?

    if supervisor_id == id
      errors.add(:supervisor_id, "cannot be yourself")
    end
  end
end
