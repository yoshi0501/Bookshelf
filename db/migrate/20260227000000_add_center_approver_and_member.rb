# frozen_string_literal: true

class AddCenterApproverAndMember < ActiveRecord::Migration[7.1]
  def change
    # 請求センターに承認者を1人紐付け（異動時はこの1件を更新すればよい）
    add_reference :customers, :approver_user_profile, null: true, foreign_key: { to_table: :user_profiles }

    # メンバーの所属請求センター（異動時はここを更新）
    add_reference :user_profiles, :billing_center, null: true, foreign_key: { to_table: :customers }
  end
end
