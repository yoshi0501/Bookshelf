# frozen_string_literal: true

module Admin
  class CompanyPaymentsController < ApplicationController
    before_action :require_internal_admin
    before_action :set_company_payment, only: %i[show edit update destroy]
    before_action :set_company_for_new, only: %i[new create]

    def index
      scope = policy_scope(CompanyPayment).includes(:company).by_period_desc
      @filter = params[:filter]
      case @filter
      when "unpaid"
        scope = scope.unpaid
      when "overdue"
        scope = scope.overdue
      when "paid"
        scope = scope.paid
      end
      @pagy, @company_payments = pagy(scope)
    end

    def show
      authorize @company_payment
    end

    def new
      @company_payment = CompanyPayment.new(
        company_id: @company&.id,
        year: params[:year]&.to_i || Date.current.year,
        month: params[:month]&.to_i || Date.current.month
      )
      @companies = policy_scope(Company).active.order(:code)
      authorize @company_payment
    end

    def create
      @company_payment = CompanyPayment.new(company_payment_params)
      authorize @company_payment

      if @company_payment.save
        redirect_to admin_company_payments_path, notice: t("company_payments.created")
      else
        @companies = policy_scope(Company).active.order(:code)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @company_payment
    end

    def update
      authorize @company_payment
      attrs = company_payment_params.except(:company_id)
      if @company_payment.update(attrs)
        redirect_to admin_company_payments_path, notice: t("company_payments.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @company_payment
      company = @company_payment.company
      if @company_payment.destroy
        redirect_to admin_company_path(company), notice: t("company_payments.destroyed")
      else
        redirect_to admin_company_payment_path(@company_payment), alert: t("company_payments.destroy_failed")
      end
    end

    private

    def require_internal_admin
      unless current_user.internal_admin?
        redirect_to root_path, alert: t("pundit.not_authorized")
      end
    end

    def set_company_payment
      @company_payment = policy_scope(CompanyPayment).find(params[:id])
    end

    def set_company_for_new
      @company = policy_scope(Company).find_by(id: params[:company_id]) if params[:company_id].present?
    end

    def company_payment_params
      params.require(:company_payment).permit(:company_id, :year, :month, :due_date, :paid_at, :amount, :memo)
    end
  end
end
