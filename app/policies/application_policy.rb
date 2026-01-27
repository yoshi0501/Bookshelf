# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  # Default: deny all
  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end

  private

  # Helper methods for authorization checks

  def user_profile
    @user_profile ||= user&.user_profile
  end

  def user_company
    @user_company ||= user&.current_company
  end

  def user_company_id
    @user_company_id ||= user&.company_id
  end

  def active_user?
    user_profile&.active?
  end

  def internal_admin?
    user_profile&.role_internal_admin?
  end

  def company_admin?
    user_profile&.role_company_admin?
  end

  def admin_or_company_admin?
    internal_admin? || company_admin?
  end

  # CRITICAL: Check if record belongs to user's company
  def same_company?
    return true if internal_admin?
    return false unless user_company_id && record.respond_to?(:company_id)

    record.company_id == user_company_id
  end
end
