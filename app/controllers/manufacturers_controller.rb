# frozen_string_literal: true

class ManufacturersController < ApplicationController
  before_action :set_manufacturer, only: %i[show edit update destroy]

  def index
    scope = policy_scope(Manufacturer).ordered_by_code
    @pagy, @manufacturers = pagy(scope)
  end

  def show
    authorize @manufacturer
  end

  def new
    @manufacturer = Manufacturer.new
    authorize @manufacturer
  end

  def edit
    authorize @manufacturer
  end

  def create
    @manufacturer = Manufacturer.new(manufacturer_params)
    authorize @manufacturer

    if @manufacturer.save
      redirect_to @manufacturer, notice: t("manufacturers.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @manufacturer
    if @manufacturer.update(manufacturer_params)
      redirect_to @manufacturer, notice: t("manufacturers.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @manufacturer
    if @manufacturer.items.any?
      redirect_to manufacturers_path, alert: t("manufacturers.destroy_has_items")
    elsif @manufacturer.destroy
      redirect_to manufacturers_path, notice: t("manufacturers.destroyed")
    else
      redirect_to @manufacturer, alert: t("manufacturers.destroy_failed")
    end
  end

  private

  def set_manufacturer
    @manufacturer = policy_scope(Manufacturer).find(params[:id])
  end

  def manufacturer_params
    permitted = params.require(:manufacturer).permit(
      %i[code name email phone postal_code prefecture city address1 address2 is_active payment_terms],
      "domains" => []
    )
    if permitted["domains"].is_a?(Array) && permitted["domains"].length == 1 && permitted["domains"][0].is_a?(String)
      permitted["domains"] = permitted["domains"][0].split("\n").map(&:strip).reject(&:blank?)
    end
    permitted
  end
end
