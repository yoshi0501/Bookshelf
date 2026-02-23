# frozen_string_literal: true

class AccessLogPolicy < ApplicationPolicy
  def index?
    internal_admin?
  end

  def show?
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
