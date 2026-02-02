# frozen_string_literal: true

  module Admin
  class UserProfilesController < ApplicationController
    before_action :set_user_profile, only: %i[show edit update change_role]
    before_action :load_supervisor_options, only: %i[edit update]

    def index
      # 会社一覧を取得（Internal Adminは全社、Company Adminは自社のみ）
      if current_user.internal_admin?
        @companies = Company.active.order(:code)
      else
        @companies = [current_company].compact
      end

      # 選択された会社（パラメータから、またはデフォルトで最初の会社）
      selected_company_id = params[:company_id]&.to_i
      if selected_company_id && @companies.map(&:id).include?(selected_company_id)
        @selected_company = Company.find(selected_company_id)
      else
        @selected_company = @companies.first
      end

      # 選択された会社のメンバーを取得
      if @selected_company
        user_profiles_scope = policy_scope(UserProfile)
          .includes(:user, :company, :supervisor)
          .active_members
          .for_company(@selected_company)
          .order(:name)
      else
        user_profiles_scope = policy_scope(UserProfile).none
      end

      @pagy, @user_profiles = pagy(user_profiles_scope)
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

    def load_supervisor_options
      # 同じ会社の管理者または内部管理者を上司候補として取得
      @supervisor_options = UserProfile
        .for_company(current_company)
        .active_members
        .where(role: [:company_admin, :internal_admin])
        .where.not(id: @user_profile&.id)
        .includes(:user)
        .order(:name)
        .map { |profile| [profile.name, profile.id] }
    end

    def user_profile_params
      params.require(:user_profile).permit(:name, :phone, :supervisor_id)
    end
  end
end
