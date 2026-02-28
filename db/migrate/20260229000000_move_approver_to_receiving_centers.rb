# frozen_string_literal: true

# 承認者を請求センターから受注センターに移行する。
# 請求センターに設定されていた承認者をクリアする（受注センターのみ承認者を設定可能に変更したため）
class MoveApproverToReceivingCenters < ActiveRecord::Migration[7.1]
  def up
    # 請求センターの承認者をクリア（受注センターのみ承認者を設定可能になったため）
    Customer.where(is_billing_center: true).where.not(approver_user_profile_id: nil).update_all(approver_user_profile_id: nil)
  end

  def down
    # ロールバック時は何もしない（元の状態に戻せない）
  end
end
