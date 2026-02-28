# frozen_string_literal: true

  module Admin
  class UserProfilesController < ApplicationController
    before_action :set_user_profile, only: %i[show edit update change_role]
    before_action :load_billing_center_options, only: %i[edit update]

    def index
      # 会社一覧を取得（Internal Adminは全社、Company Adminは自社のみ）
      if current_user.internal_admin?
        @companies = Company.active.order(:code)
      else
        @companies = [current_company].compact
      end

      # 選択された会社（unassigned / manufacturers / 会社ID、内部管理者のみ複数タブ）
      selected_company_id = params[:company_id].to_s
      if selected_company_id == "unassigned" && current_user.internal_admin?
        @selected_company = nil
        @show_unassigned = true
        @show_manufacturers = false
      elsif selected_company_id == "manufacturers" && current_user.internal_admin?
        @selected_company = nil
        @show_unassigned = false
        @show_manufacturers = true
      elsif selected_company_id.present? && @companies.map(&:id).include?(selected_company_id.to_i)
        @selected_company = Company.find(selected_company_id.to_i)
        @show_unassigned = false
        @show_manufacturers = false
      else
        @selected_company = @companies.first
        @show_unassigned = false
        @show_manufacturers = false
      end

      # メンバー一覧（未割り当て / メーカーアカウント / 会社別）
      if @show_unassigned
        user_profiles_scope = policy_scope(UserProfile)
          .includes(:user, :company, :manufacturer)
          .where(member_status: :unassigned)
          .order(:name)
      elsif @show_manufacturers
        user_profiles_scope = policy_scope(UserProfile)
          .includes(:user, :company, :manufacturer)
          .manufacturer_accounts
          .order(:name)
      elsif @selected_company
        base = policy_scope(UserProfile).includes(:user, :company, :manufacturer).active_members
        user_profiles_scope = current_user.internal_admin? ?
          base.for_company_including_manufacturers(@selected_company) :
          base.for_company(@selected_company)
        user_profiles_scope = user_profiles_scope.order(:name)
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
      @manufacturers = current_user.internal_admin? ? Manufacturer.ordered_by_code : []
    end

    def update
      authorize @user_profile

      attrs = user_profile_params.to_h
      # メーカーを割り当てた場合は会社に属さず（プラットフォーム共通）、有効化してログイン可能に
      if attrs["manufacturer_id"].present?
        attrs["company_id"] = nil
        attrs["member_status"] = "active" if @user_profile.member_status != "active"
      elsif attrs["manufacturer_id"].to_s == ""
        # メーカーを外した場合は company_id はそのまま
      end

      if @user_profile.update(attrs)
        redirect_to admin_user_profile_path(@user_profile), notice: t("user_profiles.updated")
      else
        @manufacturers = current_user.internal_admin? ? Manufacturer.ordered_by_code : []
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

    def load_billing_center_options
      target_company = @user_profile&.company
      if target_company
        @billing_center_options = Customer
          .for_company(target_company)
          .billing_centers
          .active
          .order(:center_code)
          .map { |c| [c.display_name, c.id] }
      else
        @billing_center_options = []
      end
    end

    def user_profile_params
      permitted = %i[name phone payment_terms billing_center_id]
      permitted += %i[manufacturer_id company_id] if current_user.internal_admin?
      params.require(:user_profile).permit(permitted)
    end
  end
end
