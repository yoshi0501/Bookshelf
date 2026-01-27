# frozen_string_literal: true

class ApprovalRequest < ApplicationRecord
  include MultiTenant
  include Auditable

  # Enums
  enum :status, { pending: 0, approved: 1, rejected: 2 }, prefix: true

  # Associations
  belongs_to :user_profile
  belongs_to :reviewed_by, class_name: "User", optional: true

  # Validations
  validates :status, presence: true
  validates :user_profile_id, uniqueness: { scope: :company_id, message: "already has a pending request" },
            if: :status_pending?
  validate :reviewer_must_be_company_admin, if: :reviewed?

  # Scopes
  scope :pending_for_company, ->(company) { for_company(company).status_pending }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  after_update :update_user_profile_status, if: :saved_change_to_status?

  # Instance methods
  def approve!(reviewer)
    transaction do
      update!(
        status: :approved,
        reviewed_by: reviewer,
        reviewed_at: Time.current
      )
    end
  end

  def reject!(reviewer, comment = nil)
    transaction do
      update!(
        status: :rejected,
        reviewed_by: reviewer,
        reviewed_at: Time.current,
        review_comment: comment
      )
    end
  end

  private

  def reviewed?
    reviewed_by_id.present?
  end

  def reviewer_must_be_company_admin
    return if reviewed_by.blank?

    profile = reviewed_by.user_profile
    return if profile&.role_internal_admin?
    return if profile&.role_company_admin? && profile&.company_id == company_id

    errors.add(:reviewed_by, "must be an admin of the company")
  end

  def update_user_profile_status
    case status
    when "approved"
      user_profile.update!(member_status: :active)
    when "rejected"
      user_profile.update!(member_status: :rejected)
    end
  end
end
