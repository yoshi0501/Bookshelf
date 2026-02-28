# frozen_string_literal: true

class OrderApprovalRequestPolicy < ApplicationPolicy
  def index?
    (admin_or_company_admin? || is_receiving_center_approver?) && active_user?
  end

  def show?
    (admin_or_company_admin? || is_receiving_center_approver?) && active_user? && same_company?
  end

  def approve?
    (admin_or_company_admin? || is_receiving_center_approver?) && active_user? && same_company? && record.status_pending?
  end

  def reject?
    (admin_or_company_admin? || is_receiving_center_approver?) && active_user? && same_company? && record.status_pending?
  end

  private

  def is_receiving_center_approver?
    return false unless record&.order&.customer
    return false unless user&.user_profile

    # 受注センター（配送先）の承認者が現在のユーザーかチェック
    record.order.customer.approver_user_profile_id == user.user_profile.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.user_profile&.active?

      if user.user_profile.role_internal_admin?
        scope.all
      elsif user.user_profile.role_company_admin?
        # 会社管理者は自社の全ての承認依頼を見れる
        scope.for_company(user.current_company)
      else
        # 受注センターの承認者は、自分が承認者になっているセンター宛ての承認依頼のみ見れる
        scope.joins(order: :customer)
          .where(customers: { approver_user_profile_id: user.user_profile.id })
          .for_company(user.current_company)
      end
    end
  end
end
