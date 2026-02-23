# frozen_string_literal: true

module Admin
  class IssuerSettingsController < ApplicationController
    before_action :require_internal_admin
    before_action :set_issuer_setting, only: %i[show edit update]

    def show
      authorize @issuer_setting
    end

    def edit
      authorize @issuer_setting
    end

    def update
      authorize @issuer_setting
      if @issuer_setting.update(issuer_setting_params)
        redirect_to admin_issuer_setting_path, notice: t("issuer_settings.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def require_internal_admin
      unless current_user&.user_profile&.role_internal_admin?
        redirect_to root_path, alert: t("pundit.not_authorized")
      end
    end

    def set_issuer_setting
      @issuer_setting = IssuerSetting.current
    end

    def issuer_setting_params
      params.require(:issuer_setting).permit(
        :name, :postal_code, :prefecture, :city, :address1, :address2,
        :phone, :fax, :registration_number, :bank_account_1, :bank_account_2
      )
    end
  end
end
