# frozen_string_literal: true

module Admin
  class CompaniesController < ApplicationController
    before_action :set_company, only: %i[show edit update]
    before_action :require_internal_admin, except: %i[show]

    def index
      @pagy, @companies = pagy(
        policy_scope(Company).order(:code)
      )
    end

    def show
      authorize @company
    end

    def new
      @company = Company.new
      authorize @company
    end

    def edit
      authorize @company
    end

    def create
      @company = Company.new(company_params)
      authorize @company

      if @company.save
        redirect_to admin_company_path(@company), notice: t("companies.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      authorize @company

      if @company.update(company_params)
        redirect_to admin_company_path(@company), notice: t("companies.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def require_internal_admin
      unless current_user.internal_admin?
        redirect_to root_path, alert: t("pundit.not_authorized")
      end
    end

    def set_company
      @company = Company.find(params[:id])
    end

    def company_params
      permitted = params.require(:company).permit(
        :name, :code, :order_prefix, :is_active, "domains" => []
      )
      
      # Convert textarea domains to array if it's a string
      if permitted["domains"].is_a?(Array) && permitted["domains"].length == 1 && permitted["domains"][0].is_a?(String)
        # Split by newlines and filter out empty lines
        permitted["domains"] = permitted["domains"][0].split("\n").map(&:strip).reject(&:blank?)
      end
      
      permitted
    end
  end
end
