# frozen_string_literal: true

class OrdersController < ApplicationController
  before_action :set_order, only: %i[show edit update destroy ship deliver cancel]
  before_action :load_form_data, only: %i[new create edit update]

  def index
    orders = policy_scope(Order).recent.includes(:customer, :ordered_by_user)

    # Filters
    orders = orders.search_by_order_no(params[:order_no]) if params[:order_no].present?
    orders = orders.by_status(params[:status]) if params[:status].present?
    if params[:date_from].present? && params[:date_to].present?
      orders = orders.by_date_range(params[:date_from], params[:date_to])
    end

    @pagy, @orders = pagy(orders)
  end

  def show
    authorize @order
    @order_lines = @order.order_lines.includes(:item).ordered_by_item
  end

  def new
    @order = Order.new(company: current_company, order_date: Date.current)
    @order.order_lines.build
    authorize @order
  end

  def edit
    authorize @order
    @order.order_lines.build if @order.order_lines.empty?
  end

  def create
    @order = Order.new(order_params)
    @order.company = current_company
    @order.ordered_by_user = current_user
    authorize @order

    if @order.save
      @order.recalculate_totals!
      
      # 承認依頼を作成してメール送信（通常ユーザーの場合のみ）
      unless current_user.company_admin? || current_user.internal_admin?
        create_approval_request_and_send_email
      else
        # 管理者の場合は自動承認
        @order.update!(shipping_status: :confirmed)
      end
      
      redirect_to @order, notice: t("orders.created")
    else
      @order.order_lines.build if @order.order_lines.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @order

    if @order.update(order_params)
      @order.recalculate_totals!
      redirect_to @order, notice: t("orders.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @order

    if @order.cancel!
      redirect_to orders_path, notice: t("orders.cancelled")
    else
      redirect_to @order, alert: t("orders.cancel_failed")
    end
  end

  def ship
    authorize @order

    if @order.ship!(params[:tracking_no], params[:ship_date] || Date.current)
      redirect_to @order, notice: t("orders.shipped")
    else
      redirect_to @order, alert: t("orders.ship_failed")
    end
  end

  def deliver
    authorize @order

    if @order.deliver!(params[:delivered_date] || Date.current)
      redirect_to @order, notice: t("orders.delivered")
    else
      redirect_to @order, alert: t("orders.deliver_failed")
    end
  end

  def cancel
    authorize @order

    if @order.cancel!
      redirect_to @order, notice: t("orders.cancelled")
    else
      redirect_to @order, alert: t("orders.cancel_failed")
    end
  end

  def export
    authorize Order, :export?

    orders = policy_scope(Order).includes(:order_lines, :customer, :items)

    # Apply same filters as index
    orders = orders.search_by_order_no(params[:order_no]) if params[:order_no].present?
    orders = orders.by_status(params[:status]) if params[:status].present?
    if params[:date_from].present? && params[:date_to].present?
      orders = orders.by_date_range(params[:date_from], params[:date_to])
    end

    respond_to do |format|
      format.csv do
        send_data generate_csv(orders),
          filename: "orders_#{Date.current.strftime('%Y%m%d')}.csv",
          type: "text/csv; charset=utf-8"

        IntegrationLog.log_success(
          company: current_company,
          type: "csv_export",
          payload: { count: orders.count, exported_at: Time.current }
        )
      end
    end
  end

  private

  def set_order
    @order = policy_scope(Order).find(params[:id])
  end

  def load_form_data
    @customers = policy_scope(Customer).active.order(:center_code)
    @items = policy_scope(Item).active.ordered_by_code
  end

  def order_params
    params.require(:order).permit(
      :order_date, :customer_id, :shipping_status,
      :ship_date, :tracking_no, :delivered_date,
      order_lines_attributes: %i[id item_id quantity _destroy]
    ).tap do |permitted|
      # Ensure company_id is set for nested order_lines
      if permitted[:order_lines_attributes].present?
        permitted[:order_lines_attributes].each do |_, line_attrs|
          line_attrs[:company_id] = current_company.id if line_attrs[:item_id].present?
        end
      end
    end
  end

  def create_approval_request_and_send_email
    # 発注者の上司を取得
    supervisor = current_user.user_profile.supervisor_user
    
    # 上司が設定されていない場合は承認フローをスキップして自動承認
    if supervisor.nil?
      @order.update!(shipping_status: :confirmed)
      return
    end

    # 上司が設定されている場合は承認依頼を作成してメール送信
    approval_request = @order.build_order_approval_request(
      company: @order.company,
      status: :pending
    )
    approval_request.save!

    # 上司にメール送信
    OrderMailer.approval_request(@order, [supervisor]).deliver_later
  end

  def generate_csv(orders)
    require "csv"

    CSV.generate(headers: true, encoding: "UTF-8") do |csv|
      csv << %w[
        order_no order_date customer_code customer_name
        shipping_status ship_date tracking_no delivered_date
        total_amount co2_total
        item_code item_name quantity unit_price amount
      ]

      orders.find_each do |order|
        order.order_lines.each do |line|
          csv << [
            order.order_no,
            order.order_date,
            order.customer.center_code,
            order.customer.center_name,
            order.shipping_status,
            order.ship_date,
            order.tracking_no,
            order.delivered_date,
            order.total_amount,
            order.co2_total,
            line.item_code,
            line.item_name,
            line.quantity,
            line.unit_price_snapshot,
            line.amount
          ]
        end
      end
    end
  end
end
