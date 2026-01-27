# frozen_string_literal: true

class CustomersController < ApplicationController
  before_action :set_customer, only: %i[show edit update destroy]

  def index
    @pagy, @customers = pagy(
      policy_scope(Customer).active.order(:center_code)
    )
  end

  def show
    authorize @customer
  end

  def new
    @customer = Customer.new(company: current_company)
    authorize @customer
  end

  def edit
    authorize @customer
  end

  def create
    @customer = Customer.new(customer_params)
    @customer.company = current_company
    authorize @customer

    if @customer.save
      redirect_to @customer, notice: t("customers.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @customer

    if @customer.update(customer_params)
      redirect_to @customer, notice: t("customers.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @customer

    if @customer.update(is_active: false)
      redirect_to customers_path, notice: t("customers.deactivated")
    else
      redirect_to @customer, alert: t("customers.deactivate_failed")
    end
  end

  private

  def set_customer
    @customer = policy_scope(Customer).find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(
      :center_code, :center_name, :postal_code, :prefecture,
      :city, :address1, :address2, :is_active
    )
  end
end
