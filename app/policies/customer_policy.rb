# frozen_string_literal: true

class CustomerPolicy < ApplicationPolicy
  def index?
    admin_or_company_admin? && active_user?
  end

  def show?
    admin_or_company_admin? && active_user? && same_company?
  end

  def create?
    admin_or_company_admin? && active_user?
  end

  def update?
    admin_or_company_admin? && active_user? && same_company?
  end

  def destroy?
    admin_or_company_admin? && same_company?
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
