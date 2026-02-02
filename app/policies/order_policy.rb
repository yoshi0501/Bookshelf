# frozen_string_literal: true

class OrderPolicy < ApplicationPolicy
  def index?
    active_user?
  end

  def show?
    active_user? && same_company?
  end

  def create?
    # Internal Adminは発注を作成できない（会社に紐づいていないため）
    active_user? && !internal_admin?
  end

  def update?
    active_user? && same_company? && record.can_be_edited?
  end

  def destroy?
    admin_or_company_admin? && same_company? && record.can_be_cancelled?
  end

  def ship?
    active_user? && same_company? && record.shipping_status_confirmed?
  end

  def deliver?
    active_user? && same_company? && record.shipping_status_shipped?
  end

  def cancel?
    active_user? && same_company? && record.can_be_cancelled?
  end

  def export?
    # Internal Adminは発注のエクスポートはできない（会社に紐づいていないため）
    active_user? && !internal_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.user_profile&.active?

      if user.user_profile.role_internal_admin?
        scope.all
      else
        scope.for_company(user.current_company)
      end
    end
  end
end
