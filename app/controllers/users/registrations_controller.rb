# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :validate_email_domain, only: [:create]

    protected

    def validate_email_domain
      email = sign_up_params[:email]
      company = Company.find_by_email_domain(email)

      if company.nil?
        flash[:alert] = t("devise.registrations.invalid_email_domain")
        redirect_to new_user_registration_path and return
      end
    end

    def after_sign_up_path_for(resource)
      pending_approval_path
    end

    def after_inactive_sign_up_path_for(resource)
      pending_approval_path
    end

    def after_update_path_for(resource)
      edit_user_registration_path
    end

    private

    def sign_up_params
      params.require(:user).permit(:email, :password, :password_confirmation)
    end

    def account_update_params
      params.require(:user).permit(:email, :password, :password_confirmation, :current_password)
    end

    # Override to allow password update without current_password if password is blank
    def update_resource(resource, params)
      if params[:password].blank?
        params.delete(:password)
        params.delete(:password_confirmation) if params[:password_confirmation].blank?
      end
      super
    end
  end
end
