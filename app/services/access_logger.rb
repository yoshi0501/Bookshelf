# frozen_string_literal: true

# 重要操作のみを access_logs に記録する。
class AccessLogger
  # 記録対象の (controller_path, action_name) 一覧
  CRITICAL_ACTIONS = [
    # 発注
    %w[orders create],
    %w[orders update],
    %w[orders destroy],
    %w[orders ship],
    %w[orders deliver],
    %w[orders cancel],
    %w[orders export],
    # 発注承認
    %w[order_approval_requests approve],
    %w[order_approval_requests reject],
    # 顧客・センター
    %w[customers create],
    %w[customers update],
    %w[customers destroy],
    %w[customers download_invoice],
    %w[customers download_invoices_by_center],
    %w[customers download_statement],
    %w[customers import],
    %w[customers download_invoices_bulk],
    # 商品
    %w[items create],
    %w[items update],
    %w[items destroy],
    %w[items import],
    # メーカー
    %w[manufacturers create],
    %w[manufacturers update],
    %w[manufacturers destroy],
    # 発送依頼
    %w[shipping_requests register_shipment],
    %w[shipping_requests register_shipment_import],
    # 管理: 会社
    %w[admin/companies create],
    %w[admin/companies update],
    # 管理: 入金
    %w[admin/company_payments create],
    %w[admin/company_payments update],
    %w[admin/company_payments destroy],
    # 管理: メンバー承認
    %w[admin/approval_requests approve],
    %w[admin/approval_requests reject],
    # 管理: ユーザー
    %w[admin/user_profiles update],
    %w[admin/user_profiles change_role],
    # 管理: 発行元設定
    %w[admin/issuer_settings update],
    # 管理: アクセスログ参照
    %w[admin/access_logs index],
  ].freeze

  class << self
    def log!(controller)
      return unless critical_action?(controller)

      user = controller.current_user
      AccessLog.create!(
        user_id: user&.id,
        user_name: user&.user_profile&.name || "（未ログイン）",
        user_email: user&.email,
        company_id: user&.company_id,
        controller_path: controller.controller_path,
        action_name: controller.action_name,
        request_path: controller.request.path,
        request_method: controller.request.request_method,
        ip_address: controller.request.remote_ip,
        user_agent: controller.request.user_agent&.truncate(500)
      )
    rescue => e
      Rails.logger.error "[AccessLogger] Failed to log: #{e.message}"
    end

    def critical_action?(controller)
      CRITICAL_ACTIONS.include?([controller.controller_path, controller.action_name])
    end
  end
end
