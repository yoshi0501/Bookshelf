# frozen_string_literal: true

class UserProfilePolicy < ApplicationPolicy
  def index?
    admin_or_company_admin? && active_user?
  end

  def show?
    # Users can see their own profile, admins can see company profiles
    return true if record.user_id == user.id
    admin_or_company_admin? && active_user? && same_company?
  end

  def update?
    # Users can update their own profile (limited fields)
    # Company admins can update role for company members
    return own_profile_update? if record.user_id == user.id
    admin_or_company_admin? && active_user? && same_company?
  end

  def change_role?
    admin_or_company_admin? && active_user? && same_company? && record.user_id != user.id
  end

  private

  def own_profile_update?
    active_user?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.user_profile&.active?

      if user.user_profile.role_internal_admin?
        scope.all
      elsif user.user_profile.role_company_admin?
        scope.for_company(user.current_company)
      else
        scope.where(user_id: user.id)
      end
    end
  end
end
