# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  protect_from_forgery with: :exception

  before_action :authenticate_user!
  before_action :check_member_status
  before_action :set_paper_trail_whodunnit
  before_action :set_paper_trail_request_info

  after_action :verify_authorized, except: :index, unless: :skip_pundit?
  after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  helper_method :current_company

  private

  def current_company
    current_user&.current_company
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

  # Custom Devise location after sign in
  def after_sign_in_path_for(resource)
    if resource.user_profile&.pending?
      pending_approval_path
    else
      stored_location_for(resource) || dashboard_path
    end
  end
end
