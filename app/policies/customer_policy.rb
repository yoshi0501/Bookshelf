# frozen_string_literal: true

class CustomerPolicy < ApplicationPolicy
  def index?
    # 全ユーザーが閲覧可能（Internal Adminは全社、会社管理者は自社のみ）
    active_user?
  end

  def show?
    active_user? && (internal_admin? || same_company?)
  end

  def create?
    # 顧客（センター）の作成はInternal Adminのみ
    internal_admin?
  end

  def update?
    # 顧客（センター）の編集はInternal Adminのみ
    internal_admin?
  end

  def destroy?
    # 顧客（センター）の削除はInternal Adminのみ
    internal_admin?
  end

  def import?
    # CSVインポートはInternal Adminのみ
    internal_admin?
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
