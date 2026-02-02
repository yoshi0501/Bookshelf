# frozen_string_literal: true

class OrderApprovalRequestPolicy < ApplicationPolicy
  def index?
    (admin_or_company_admin? || is_supervisor?) && active_user?
  end

  def show?
    (admin_or_company_admin? || is_supervisor?) && active_user? && same_company?
  end

  def approve?
    (admin_or_company_admin? || is_supervisor?) && active_user? && same_company? && record.status_pending?
  end

  def reject?
    (admin_or_company_admin? || is_supervisor?) && active_user? && same_company? && record.status_pending?
  end

  private

  def is_supervisor?
    return false unless record&.order&.ordered_by_user&.user_profile

    # 発注者の上司が現在のユーザーかチェック
    record.order.ordered_by_user.user_profile.supervisor_id == user.user_profile.id
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
        # 通常ユーザーは自分が上司になっている承認依頼のみ見れる
        subordinate_user_ids = UserProfile.where(supervisor_id: user.user_profile.id).pluck(:user_id)
        scope.joins(:order)
          .where(orders: { ordered_by_user_id: subordinate_user_ids })
          .for_company(user.current_company)
      end
    end
  end
end
