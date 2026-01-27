# frozen_string_literal: true

class ApprovalRequestPolicy < ApplicationPolicy
  def index?
    admin_or_company_admin? && active_user?
  end

  def show?
    admin_or_company_admin? && active_user? && same_company?
  end

  def approve?
    admin_or_company_admin? && active_user? && same_company? && record.status_pending?
  end

  def reject?
    admin_or_company_admin? && active_user? && same_company? && record.status_pending?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.user_profile&.active?
      return scope.none unless user.user_profile.can_approve_members?

      if user.user_profile.role_internal_admin?
        scope.all
      else
        scope.for_company(user.current_company)
      end
    end
  end
end
