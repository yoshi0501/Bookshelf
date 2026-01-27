# frozen_string_literal: true

module Admin
  class UserProfilesController < ApplicationController
    before_action :set_user_profile, only: %i[show edit update change_role]

    def index
      @pagy, @user_profiles = pagy(
        policy_scope(UserProfile)
          .includes(:user, :company)
          .active_members
          .order(:name)
      )
    end

    def show
      authorize @user_profile
    end

    def edit
      authorize @user_profile
    end

    def update
      authorize @user_profile

      if @user_profile.update(user_profile_params)
        redirect_to admin_user_profile_path(@user_profile), notice: t("user_profiles.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def change_role
      authorize @user_profile

      new_role = params[:role]
      unless UserProfile.roles.key?(new_role)
        redirect_to admin_user_profile_path(@user_profile), alert: t("user_profiles.invalid_role")
        return
      end

      # Prevent changing own role
      if @user_profile.user_id == current_user.id
        redirect_to admin_user_profile_path(@user_profile), alert: t("user_profiles.cannot_change_own_role")
        return
      end

      # Prevent normal users from becoming internal_admin
      if new_role == "internal_admin" && !current_user.internal_admin?
        redirect_to admin_user_profile_path(@user_profile), alert: t("user_profiles.cannot_grant_internal_admin")
        return
      end

      if @user_profile.update(role: new_role)
        redirect_to admin_user_profile_path(@user_profile), notice: t("user_profiles.role_changed")
      else
        redirect_to admin_user_profile_path(@user_profile), alert: t("user_profiles.role_change_failed")
      end
    end

    private

    def set_user_profile
      @user_profile = policy_scope(UserProfile).find(params[:id])
    end

    def user_profile_params
      params.require(:user_profile).permit(:name, :phone)
    end
  end
end
