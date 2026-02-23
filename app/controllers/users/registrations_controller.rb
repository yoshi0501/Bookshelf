# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :validate_email_domain, only: [:create]
    before_action :authenticate_user!, only: [:verify_password]

    def create
      build_resource(sign_up_params)
      resource.save
      yield resource if block_given?
      if resource.persisted?
        if resource.active_for_authentication?
          set_flash_message! :notice, :signed_up
          sign_up(resource_name, resource)
          respond_with resource, location: after_sign_up_path_for(resource)
        else
          set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
          expire_data_after_sign_in!
          respond_with resource, location: after_inactive_sign_up_path_for(resource)
        end
      else
        clean_up_passwords resource
        set_minimum_password_length
        render :new, status: :unprocessable_entity
      end
    end

    def verify_password
      if params[:password].blank?
        flash[:alert] = t("devise.registrations.verify_password.blank")
      elsif current_user.valid_password?(params[:password])
        flash[:notice] = t("devise.registrations.verify_password.correct")
      else
        flash[:alert] = t("devise.registrations.verify_password.incorrect")
      end
      redirect_to edit_user_registration_path
    end

    protected

    def validate_email_domain
      email = params.dig(:user, :email)
      return if email.blank?

      return if Company.find_by_email_domain(email).present?
      return if Manufacturer.find_by_email_domain(email).present?

      flash[:alert] = t("devise.registrations.invalid_email_domain")
      redirect_to new_user_registration_path
      throw(:abort)
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
