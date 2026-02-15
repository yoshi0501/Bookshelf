# frozen_string_literal: true

class ManufacturerPolicy < ApplicationPolicy
  def index?
    active_user?
  end

  def show?
    active_user?
  end

  # 発送依頼PDF（show と同じ権限。メーカーは自社のみ policy_scope で制限）
  def pdf?
    show?
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
      return scope.none unless user&.user_profile&.active?

      # メーカーユーザーは自分のメーカーのみ
      if user.user_profile.respond_to?(:manufacturer_user?) && user.user_profile.manufacturer_user?
        return scope.none unless user.user_profile.manufacturer_id
        return scope.where(id: user.user_profile.manufacturer_id)
      end

      # プラットフォーム共通マスタ: 内部管理者は全件、利用会社は全件（商品に紐づけるため）
      scope.all
    end
  end
end
