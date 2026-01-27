# frozen_string_literal: true

class ItemsController < ApplicationController
  before_action :set_item, only: %i[show edit update destroy]

  def index
    @pagy, @items = pagy(
      policy_scope(Item).active.ordered_by_code
    )
  end

  def show
    authorize @item
  end

  def new
    @item = Item.new(company: current_company)
    authorize @item
  end

  def edit
    authorize @item
  end

  def create
    @item = Item.new(item_params)
    @item.company = current_company
    authorize @item

    if @item.save
      redirect_to @item, notice: t("items.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @item

    if @item.update(item_params)
      redirect_to @item, notice: t("items.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @item

    if @item.update(is_active: false)
      redirect_to items_path, notice: t("items.deactivated")
    else
      redirect_to @item, alert: t("items.deactivate_failed")
    end
  end

  private

  def set_item
    @item = policy_scope(Item).find(params[:id])
  end

  def item_params
    params.require(:item).permit(
      :item_code, :name, :unit_price, :co2_per_unit, :is_active
    )
  end
end
