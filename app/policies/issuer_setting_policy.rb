# frozen_string_literal: true

class IssuerSettingPolicy < ApplicationPolicy
  def show?
    internal_admin?
  end

  def edit?
    internal_admin?
  end

  def update?
    internal_admin?
  end
end
