# frozen_string_literal: true

require 'i18n'

class DeviseFailureApp < Devise::FailureApp
  def redirect
    store_location!
    if is_flashing_format?
      flash[:alert] = i18n_message unless flash[:notice]
    end
    redirect_to redirect_url
  end

  def i18n_message(default = nil)
    case warden_message
    when :not_found_in_database
      I18n.t("devise.failure.not_found_in_database", default: default || "メールアドレスまたはパスワードが正しくありません。")
    when :invalid
      I18n.t("devise.failure.invalid", default: default || "メールアドレスまたはパスワードが正しくありません。")
    when :invalid_token
      I18n.t("devise.failure.invalid_token", default: default || "メールアドレスまたはパスワードが正しくありません。")
    when :timeout
      I18n.t("devise.failure.timeout", default: default || "セッションが期限切れです。再度ログインしてください。")
    when :unconfirmed
      I18n.t("devise.failure.unconfirmed", default: default || "続行する前にメールアドレスを確認してください。")
    when :locked
      I18n.t("devise.failure.locked", default: default || "アカウントがロックされています。")
    when :pending_approval
      I18n.t("devise.failure.pending_approval", default: default || "アカウントは承認待ちです。")
    when :account_rejected
      I18n.t("devise.failure.account_rejected", default: default || "アカウントが拒否されました。")
    when :unassigned_company
      I18n.t("devise.failure.unassigned_company", default: default || "メールドメインがどの会社にも関連付けられていません。")
    when :inactive
      I18n.t("devise.failure.inactive", default: default || "アカウントが有効ではありません。管理者に連絡してください。")
    else
      super(default)
    end
  end
end
