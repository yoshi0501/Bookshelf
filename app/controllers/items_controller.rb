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
    @item = Item.new
    @companies = Company.active.order(:name) # 内部管理者が会社を選択
    authorize @item
  end

  def edit
    @companies = Company.active.order(:name) # 内部管理者が会社を選択
    authorize @item
  end

  def create
    @item = Item.new(item_params)
    @companies = Company.active.order(:name)
    authorize @item

    if @item.save
      # 内部管理者のみが商品の表示会社を設定可能
      update_visible_companies(@item, params[:item][:visible_company_ids])
      redirect_to @item, notice: t("items.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @companies = Company.active.order(:name)
    authorize @item

    if @item.update(item_params)
      # 内部管理者のみが商品の表示会社を設定可能
      update_visible_companies(@item, params[:item][:visible_company_ids])
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
      :company_id, :item_code, :name, :unit_price, :co2_per_unit, :is_active
    )
  end

  def update_visible_companies(item, company_ids)
    return unless current_user&.internal_admin?
    return unless company_ids

    # 既存の関連を削除
    item.item_companies.destroy_all

    # 新しい関連を作成（空の配列の場合は何もしない）
    company_ids.reject(&:blank?).each do |company_id|
      company = Company.find_by(id: company_id)
      next unless company
      # 自社の商品は自動的に表示されるので、自社以外のみ追加
      next if company.id == item.company_id

      ItemCompany.create!(item: item, company: company)
    end
  end
end
