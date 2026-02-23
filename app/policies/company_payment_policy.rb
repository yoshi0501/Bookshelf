# frozen_string_literal: true

class CompanyPaymentPolicy < ApplicationPolicy
  def index?
    internal_admin?
  end

  def show?
    internal_admin?
  end

  def new?
    internal_admin?
  end

  def create?
    internal_admin?
  end

  def edit?
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
      else
        scope.none
      end
    end
  end
end
