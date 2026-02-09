# frozen_string_literal: true

class DashboardController < ApplicationController
  def index
    # システム管理者向け: 会社・センターで絞り込み
    if current_user&.internal_admin?
      @companies = Company.active.order(:name)
      @selected_company = @companies.find_by(id: params[:company_id])
      if @selected_company
        @centers = Customer.for_company(@selected_company).order(:center_code)
        @selected_center = @centers.find_by(id: params[:center_id])
      else
        @centers = Customer.none
        @selected_center = nil
      end
    else
      # 一般・会社管理者: 自社のセンター一覧と選択（絞り込み・センター別グラフ用）
      @centers = policy_scope(Customer).order(:center_code)
      @selected_center = @centers.find_by(id: params[:center_id]) if params[:center_id].present?
    end

    scope = order_scope
    @recent_orders = scope.includes(:order_approval_request).recent.limit(10)
    @pending_approvals_count = if current_user.user_profile.can_approve_members?
      policy_scope(ApprovalRequest).status_pending.count
    else
      0
    end

    # 表示月: params[:month] (YYYY-MM) または今月
    @target_month = parse_month_param(params[:month])
    @target_month_range = @target_month.beginning_of_month..@target_month.end_of_month

    orders_in_month_scope = scope.where(order_date: @target_month_range)
    @orders_in_month = orders_in_month_scope.count
    @total_amount_in_month = orders_in_month_scope.sum(:total_amount)

    # システム管理者向け: 指定月の原価・損益
    if current_user&.internal_admin?
      order_ids = orders_in_month_scope.select(:id)
      @cost_total_in_month = OrderLine
        .where(order_id: order_ids)
        .sum("(COALESCE(cost_price_snapshot, 0) + COALESCE(shipping_cost_snapshot, 0)) * quantity")
      @profit_in_month = @total_amount_in_month - @cost_total_in_month
    end

    # グラフ用: 過去12ヶ月の月別収益（管理者は原価・損益も）
    @chart_data = build_chart_data
    # グラフ用: 過去12ヶ月の月別CO2排出量（損益と分けて表示）
    @co2_chart_data = build_co2_chart_data

    # エコ貢献: 当月のCO2削減量（換算表示用）
    co2_scope = scope.where(order_date: @target_month_range)
    @co2_reduced_kg = co2_scope.sum(:co2_total).to_f

    skip_authorization
  end

  private

  # 発注スコープ（システム管理者は会社・センター、一般・会社管理者はセンターで絞り込み可能）
  def order_scope
    base = policy_scope(Order)
    if current_user&.internal_admin?
      base = base.where(company_id: @selected_company.id) if @selected_company
      base = base.where(customer_id: @selected_center.id) if @selected_center
    else
      base = base.where(customer_id: @selected_center.id) if @selected_center.present?
    end
    base
  end

  def parse_month_param(value)
    return Date.current if value.blank?

    parts = value.to_s.split("-").map(&:to_i)
    year, month = parts[0], parts[1]
    return Date.current if year.to_i < 2000 || month.to_i < 1 || month > 12

    Date.new(year, month, 1)
  rescue ArgumentError
    Date.current
  end

  # グラフ用: 当期年度の開始日（4月1日）。例: 2025年1月→2024年4月、2025年5月→2025年4月
  def chart_fiscal_year_start
    y = Date.current.year
    y -= 1 if Date.current.month < 4
    Date.new(y, 4, 1)
  end

  def build_chart_data
    scope = order_scope

    if current_user&.internal_admin?
      # 内部管理者: 原価・損益（月別・4月〜翌3月）
      start_date = chart_fiscal_year_start
      (0...12).map do |i|
        month_start = start_date + i.months
        range = month_start..month_start.end_of_month
        orders_scope = scope.where(order_date: range)
        revenue = orders_scope.sum(:total_amount)
        order_ids = orders_scope.select(:id)
        cost = OrderLine
          .where(order_id: order_ids)
          .sum("(COALESCE(cost_price_snapshot, 0) + COALESCE(shipping_cost_snapshot, 0)) * quantity")
        {
          label: month_start.strftime("%Y年%m月"),
          cost: cost,
          profit: revenue - cost
        }
      end
    else
      # 一般・会社管理者: 月別のみ（4月〜翌3月の年度順）
      build_chart_data_by_month(scope)
    end
  end

  def build_chart_data_by_month(scope)
    start_date = chart_fiscal_year_start
    (0...12).map do |i|
      month_start = start_date + i.months
      range = month_start..month_start.end_of_month
      orders_scope = scope.where(order_date: range)
      {
        label: month_start.strftime("%Y年%m月"),
        orders_count: orders_scope.count,
        total_amount: orders_scope.sum(:total_amount)
      }
    end
  end

  def build_co2_chart_data
    start_date = chart_fiscal_year_start
    scope = order_scope

    (0...12).map do |i|
      month_start = start_date + i.months
      range = month_start..month_start.end_of_month
      orders_scope = scope.where(order_date: range)
      co2_kg = orders_scope.sum(:co2_total)
      {
        label: month_start.strftime("%Y年%m月"),
        co2: co2_kg.to_f
      }
    end
  end
end
