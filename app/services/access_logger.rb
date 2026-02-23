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
        user_agent: controller.request.user_agent&.truncate(500),
        target_summary: target_summary_from(controller)
      )
    rescue => e
      Rails.logger.error "[AccessLogger] Failed to log: #{e.message}"
    end

    def critical_action?(controller)
      CRITICAL_ACTIONS.include?([controller.controller_path, controller.action_name])
    end

    # コントローラのインスタンス変数から操作対象を推測して「何をしたか」を生成
    def target_summary_from(controller)
      return controller.access_log_target_summary if controller.respond_to?(:access_log_target_summary, true) && controller.send(:access_log_target_summary).present?

      # 共通パターン: 各リソースの識別子を取得
      if (order = controller.instance_variable_get(:@order))
        return "発注 #{order.order_no}"
      end
      if (oar = controller.instance_variable_get(:@order_approval_request))
        return "発注 #{oar.order&.order_no}"
      end
      if (customer = controller.instance_variable_get(:@customer))
        return "センター #{customer.center_name} (#{customer.center_code})"
      end
      if (item = controller.instance_variable_get(:@item))
        return "商品 #{item.item_code} (#{item.name})"
      end
      if (manufacturer = controller.instance_variable_get(:@manufacturer))
        return "メーカー #{manufacturer.name} (#{manufacturer.code})"
      end
      if (company = controller.instance_variable_get(:@company))
        return "会社 #{company.name}"
      end
      if (payment = controller.instance_variable_get(:@company_payment))
        return "入金 #{payment.company&.name} #{payment.period_label}"
      end
      if (profile = controller.instance_variable_get(:@user_profile))
        return "ユーザー #{profile.name} (#{profile.user&.email})"
      end
      if (req = controller.instance_variable_get(:@approval_request))
        return "メンバー #{req.user_profile&.name} (#{req.user_profile&.user&.email})"
      end
      if (setting = controller.instance_variable_get(:@issuer_setting))
        return "発行元設定"
      end

      nil
    end
  end
end
