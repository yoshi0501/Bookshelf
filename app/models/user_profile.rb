# frozen_string_literal: true

class UserProfile < ApplicationRecord
  include Auditable

  # Enums
  enum :role, { normal: 0, company_admin: 1, internal_admin: 2 }, prefix: true
  enum :member_status, { pending: 0, active: 1, rejected: 2, unassigned: 3 }, prefix: true

  # Associations
  belongs_to :user
  belongs_to :company, optional: true
  has_many :approval_requests, dependent: :destroy

  # Validations
  validates :user_id, presence: true, uniqueness: true
  validates :name, presence: true, length: { maximum: 255 }
  validates :phone, length: { maximum: 50 }, allow_blank: true
  validates :role, presence: true
  validates :member_status, presence: true
  validates :company_id, presence: true, unless: :unassigned?

  # Scopes
  scope :for_company, ->(company) { where(company: company) }
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
end
