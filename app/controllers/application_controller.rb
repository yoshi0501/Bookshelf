# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  protect_from_forgery with: :exception

  before_action :authenticate_user!
  before_action :check_member_status
  before_action :restrict_manufacturer_user_to_shipping_requests
  before_action :warn_password_expiring_soon
  before_action :set_paper_trail_whodunnit
  before_action :set_paper_trail_request_info
  before_action :set_pending_order_approvals_count
  before_action :set_pending_approval_requests_count

  after_action :verify_authorized, except: :index, unless: :skip_pundit?
  after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?
  after_action :log_critical_access, unless: :skip_access_log?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  helper_method :current_company, :current_manufacturer, :manufacturer_user?

  private

  def current_company
    current_user&.current_company
  end

  def current_manufacturer
    current_user&.current_manufacturer
  end

  def manufacturer_user?
    current_user&.manufacturer_user?
  end

  def check_member_status
    return unless user_signed_in?
    return if devise_controller?

    profile = current_user.user_profile
    return if profile&.active?

    if profile&.pending?
      redirect_to pending_approval_path
    elsif profile&.rejected?
      sign_out current_user
      redirect_to new_user_session_path, alert: t("devise.failure.account_rejected")
    elsif profile&.unassigned?
      sign_out current_user
      redirect_to new_user_session_path, alert: t("devise.failure.unassigned_company")
    end
  end

  def user_not_authorized
    flash[:alert] = t("pundit.not_authorized")
    redirect_back(fallback_location: root_path)
  end

  def record_not_found
    flash[:alert] = t("errors.record_not_found")
    redirect_back(fallback_location: root_path)
  end

  def skip_pundit?
    devise_controller? || params[:controller] == "pages"
  end

  def skip_access_log?
    devise_controller? || params[:controller] == "pages"
  end

  def log_critical_access
    return unless user_signed_in?

    AccessLogger.log!(self)
  end

  # メーカーユーザーは発送依頼以外のメニューにアクセスさせない
  def restrict_manufacturer_user_to_shipping_requests
    return unless current_user&.manufacturer_user?
    return if controller_name == "shipping_requests"
    return if controller_name == "dashboard" # メーカー用ダッシュボード（自社売上）を許可
    return if controller_path.start_with?("devise/") || controller_path == "users/registrations"
    return if controller_path == "users/sessions" # ログイン・ログアウトは許可
    return if controller_path.start_with?("admin/") == false && controller_name == "pages"

    redirect_to shipping_requests_path, alert: t("pundit.not_authorized")
  end

  # パスワード有効期限の約2週間前から変更を促す
  def warn_password_expiring_soon
    return unless user_signed_in?
    return if devise_controller?
    return if controller_path == "users/registrations" && action_name == "edit"
    return unless current_user.respond_to?(:password_changed_at) && current_user.password_changed_at.present?

    expiry = current_user.password_changed_at + 90.days
    return if Time.current >= expiry # 期限切れは devise-security が処理
    return if (expiry - Time.current) > 14.days # 14日以内のときだけ促す

    days_left = ((expiry - Time.current) / 1.day).ceil
    flash.now[:warning] = t("devise.password_expiring_soon", count: days_left)
  end

  # 発注承認メニューを見れるユーザー向けに、承認待ち件数をヘッダー用にセット
  def set_pending_order_approvals_count
    return unless user_signed_in?
    return if devise_controller?
    return unless current_user.user_profile&.active?
    return unless current_user.user_profile&.can_access_admin_dashboard? || current_user.user_profile&.centers_as_approver&.any?

    scope = Pundit.policy_scope(current_user, OrderApprovalRequest)
    @pending_order_approvals_count = scope.status_pending.count
  rescue
    @pending_order_approvals_count = 0
  end

  # 承認リクエスト（ユーザー登録承認）メニューを見れるユーザー向けに、承認待ち件数をヘッダー用にセット
  def set_pending_approval_requests_count
    return unless user_signed_in?
    return if devise_controller?
    return unless current_user.user_profile&.active?
    return unless current_user.user_profile&.can_access_admin_dashboard?

    scope = Pundit.policy_scope(current_user, ApprovalRequest)
    @pending_approval_requests_count = scope.status_pending.count
  rescue
    @pending_approval_requests_count = 0
  end

  def set_paper_trail_request_info
    return unless user_signed_in?

    PaperTrail.request.controller_info = {
      request_uuid: request.uuid,
      ip_address: request.remote_ip,
      user_agent: request.user_agent&.truncate(255)
    }
  end

  # Ensure all queries are scoped to current company
  def policy_scope(scope, policy_scope_class: nil)
    super(scope, policy_scope_class: policy_scope_class)
  end
end
