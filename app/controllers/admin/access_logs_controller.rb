# frozen_string_literal: true

module Admin
  class AccessLogsController < ApplicationController
    before_action :require_internal_admin

    def index
      scope = policy_scope(AccessLog).includes(:user, :company).recent

      # 絞り込み
      scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
      scope = scope.where(company_id: params[:company_id]) if params[:company_id].present?
      scope = scope.where("user_email ILIKE ?", "%#{params[:q]}%") if params[:q].present?
      scope = scope.where("request_path ILIKE ?", "%#{params[:path]}%") if params[:path].present?
      scope = scope.where(controller_path: params[:controller_path]) if params[:controller_path].present?
      scope = scope.where(action_name: params[:action_name]) if params[:action_name].present?
      scope = scope.where(created_at: params[:from].to_date..) if params[:from].present?
      scope = scope.where(created_at: ..params[:to].to_date.end_of_day) if params[:to].present?

      @pagy, @access_logs = pagy(scope, items: 50)
    end

    private

    def require_internal_admin
      unless current_user.internal_admin?
        redirect_to root_path, alert: t("pundit.not_authorized")
      end
    end
  end
end
