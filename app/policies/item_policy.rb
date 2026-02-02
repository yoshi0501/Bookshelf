# frozen_string_literal: true

class ItemPolicy < ApplicationPolicy
  def index?
    active_user?
  end

  def show?
    return false unless active_user?
    return true if internal_admin?
    return false unless user_company_id && record.respond_to?(:company_id)
    
    # 自社の商品、または自社に表示可能な商品
    record.company_id == user_company_id || 
    record.visible_companies.exists?(id: user_company_id)
  end

  def create?
    # 商品の登録は内部管理者のみ
    internal_admin?
  end

  def update?
    # 商品の編集は内部管理者のみ
    internal_admin?
  end

  def destroy?
    # 商品の削除は内部管理者のみ
    internal_admin?
  end

  def import?
    # CSV一括登録は内部管理者のみ
    internal_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.user_profile&.active?

      if user.user_profile.role_internal_admin?
        scope.all
      else
        company = user.current_company
        # 自社の商品 + 自社に表示可能な商品
        scope.where(
          "(company_id = ? OR id IN (?))",
          company.id,
          ItemCompany.where(company: company).select(:item_id)
        )
      end
    end
  end
end
