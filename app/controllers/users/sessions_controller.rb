# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    # Override for custom session handling if needed

    protected

    def after_sign_in_path_for(resource)
      if resource.user_profile&.pending?
        pending_approval_path
      elsif resource.user_profile&.rejected?
        sign_out resource
        flash[:alert] = t("devise.failure.account_rejected")
        new_user_session_path
      elsif resource.user_profile&.unassigned?
        sign_out resource
        flash[:alert] = t("devise.failure.unassigned_company")
        new_user_session_path
      else
        stored_location_for(resource) || dashboard_path
      end
    end

    def after_sign_out_path_for(_resource_or_scope)
      new_user_session_path
    end
  end
end
