# frozen_string_literal: true

class CompanyPolicy < ApplicationPolicy
  # Only internal_admin can manage companies
  def index?
    internal_admin?
  end

  def show?
    internal_admin? || (active_user? && record.id == user_company_id)
  end

  def create?
    internal_admin?
  end

  def update?
    internal_admin?
  end

  def destroy?
    internal_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.user_profile&.role_internal_admin?
        scope.all
      elsif user&.user_profile&.active?
        scope.where(id: user.company_id)
      else
        scope.none
      end
    end
  end
end
