# frozen_string_literal: true

class ShippingRequestsController < ApplicationController
  before_action :set_manufacturer, only: %i[show pdf register_shipment register_shipment_import shipment_template]

  def index
    # index では verify_policy_scoped が走るため、早期 return の前にも policy_scope を1回呼ぶ
    policy_scope(Order)

    return redirect_to root_path, alert: t("pundit.not_authorized") unless current_company || current_user&.internal_admin? || current_user&.manufacturer_user?

    # メーカーユーザー: 自メーカーの発送依頼へリダイレクト（未設定なら案内）
    if current_user&.manufacturer_user?
      unless current_manufacturer
        return redirect_to root_path, alert: "メーカーが設定されていません。管理者に連絡してください。"
      end
      return redirect_to shipping_request_path(current_manufacturer, month: params[:month], date_from: params[:date_from], date_to: params[:date_to])
    end

    @companies = current_user&.internal_admin? ? Company.active.order(:code) : [current_company].compact
    company_id = params[:company_id]&.to_i
    @selected_company = if company_id && @companies.map(&:id).include?(company_id)
      Company.find(company_id)
    else
      @companies.first
    end

    parse_date_range_from_params

    orders_scope = policy_scope(Order)
      .for_company(@selected_company) if @selected_company
    orders_scope ||= policy_scope(Order).none
    orders_scope = orders_scope.by_date_range(@date_from, @date_to)
      .where(shipping_status: %i[confirmed shipped]) # 発送依頼対象: 確認済み・出荷済み

    order_ids = orders_scope.pluck(:id)
    # メーカーが紐づいた明細がある発注のみ。メーカー別件数
    @manufacturers_with_counts = OrderLine
      .joins(:item, :order)
      .where(order_id: order_ids)
      .where.not(items: { manufacturer_id: nil })
      .group("items.manufacturer_id")
      .count

    manufacturer_ids = @manufacturers_with_counts.keys.compact
    @manufacturers = Manufacturer.where(id: manufacturer_ids).ordered_by_code
  end

  def show
    authorize @manufacturer
    parse_date_range_from_params

    # プラットフォーム共通: このメーカーが紐づく明細がある発注を全社から取得
    order_ids = OrderLine
      .joins(:item)
      .where(items: { manufacturer_id: @manufacturer.id })
      .distinct
      .pluck(:order_id)
    orders_scope = Order
      .where(id: order_ids)
      .by_date_range(@date_from, @date_to)
      .where(shipping_status: %i[confirmed shipped])
    order_ids = orders_scope.pluck(:id)

    @lines_by_order = OrderLine
      .joins(:item, :order)
      .where(order_id: order_ids, items: { manufacturer_id: @manufacturer.id })
      .includes(:order, :item)
      .ordered_by_item
      .group_by(&:order)
  end

  # メーカーが出荷登録（運送会社・追跡番号）。発注単位または明細行（商品コード指定）単位で登録可能。
  def register_shipment
    authorize @manufacturer, :show?
    unless current_user&.manufacturer_user? && current_manufacturer&.id == @manufacturer.id
      return redirect_to shipping_request_path(@manufacturer), alert: t("pundit.not_authorized")
    end

    order = Order.find_by(id: params[:order_id])
    order_ids_with_my_items = OrderLine.joins(:item).where(items: { manufacturer_id: @manufacturer.id }).distinct.pluck(:order_id)
    unless order && order_ids_with_my_items.include?(order.id) && order.shipping_status_confirmed?
      return redirect_to shipping_request_path(@manufacturer, month: params[:month]), alert: t("shipping_requests.register_shipment.invalid_order")
    end

    unless params[:shipping_carrier].to_s.strip.present? && params[:tracking_no].to_s.strip.present?
      return redirect_to shipping_request_path(@manufacturer, month: params[:month]), alert: t("shipping_requests.register_shipment.blank_carrier_or_tracking")
    end

    ship_date = params[:ship_date].presence || Date.current
    ship_date = Date.parse(ship_date.to_s) rescue Date.current
    carrier = params[:shipping_carrier].to_s.strip
    tracking = params[:tracking_no].to_s.strip

    item_code = params[:item_code].to_s.strip.presence
    if item_code.present?
      line = OrderLine.joins(:item, :order)
        .where(orders: { id: order.id }, items: { manufacturer_id: @manufacturer.id, item_code: item_code })
        .first
      unless line
        return redirect_to shipping_request_path(@manufacturer, month: params[:month]), alert: t("shipping_requests.register_shipment.line_not_found", item_code: item_code)
      end
      line.update!(shipping_carrier: carrier, tracking_no: tracking, ship_date: ship_date)
    else
      order.ship!(tracking, ship_date, shipping_carrier: carrier)
      OrderLine.joins(:item)
        .where(order_id: order.id, items: { manufacturer_id: @manufacturer.id })
        .update_all(
          shipping_carrier: carrier,
          tracking_no: tracking,
          ship_date: ship_date
        )
    end
    redirect_to shipping_request_path(@manufacturer, month: params[:month]), notice: t("shipping_requests.register_shipment.success")
  rescue ActiveRecord::RecordNotFound
    redirect_to shipping_request_path(@manufacturer, month: params[:month]), alert: t("shipping_requests.register_shipment.invalid_order")
  end

  # メーカーが出荷登録をCSVで一括投入。発注番号のみ＝発注単位、発注番号＋商品コード＝明細行単位。
  def register_shipment_import
    authorize @manufacturer, :show?
    unless current_user&.manufacturer_user? && current_manufacturer&.id == @manufacturer.id
      return redirect_to shipping_request_path(@manufacturer), alert: t("pundit.not_authorized")
    end

    parse_date_range_from_params
    order_ids_with_my_items = OrderLine.joins(:item).where(items: { manufacturer_id: @manufacturer.id }).distinct.pluck(:order_id)
    orders_in_scope = Order.where(id: order_ids_with_my_items).by_date_range(@date_from, @date_to).where(shipping_status: :confirmed).to_a
    order_ids_set = orders_in_scope.map(&:id).to_set
    orders_by_no = orders_in_scope.index_by(&:order_no)

    file = params[:csv_file]
    unless file.present?
      return redirect_to shipping_request_path(@manufacturer, month: params[:month]), alert: t("shipping_requests.import.missing_file")
    end

    require "csv"
    csv_content = file.read.force_encoding("UTF-8")
    csv = CSV.parse(csv_content, headers: true)
    ok_count = 0
    errors = []

    csv.each_with_index do |row, idx|
      row_no = idx + 2
      order_no = row["発注番号"]&.strip.presence || row["order_no"]&.strip.presence
      item_code = row["商品コード"]&.strip.presence || row["item_code"]&.strip.presence
      carrier = row["運送会社"]&.strip.presence || row["shipping_carrier"]&.strip.presence
      tracking = row["追跡番号"]&.strip.presence || row["tracking_no"]&.strip.presence
      ship_date_str = row["出荷日"]&.strip.presence || row["ship_date"]&.strip.presence

      if order_no.blank?
        errors << { row: row_no, message: t("shipping_requests.import.blank_order_no") }
        next
      end
      unless carrier.present? && tracking.present?
        errors << { row: row_no, message: t("shipping_requests.import.blank_carrier_or_tracking") }
        next
      end

      order = orders_by_no[order_no]
      unless order && order_ids_set.include?(order.id)
        errors << { row: row_no, message: t("shipping_requests.import.order_not_found", order_no: order_no) }
        next
      end

      ship_date = ship_date_str.present? ? (Date.parse(ship_date_str) rescue Date.current) : Date.current

      if item_code.present?
        line = OrderLine.joins(:item)
          .where(order_id: order.id, items: { manufacturer_id: @manufacturer.id, item_code: item_code })
          .first
        unless line
          errors << { row: row_no, message: t("shipping_requests.import.line_not_found", order_no: order_no, item_code: item_code) }
          next
        end
        line.update!(shipping_carrier: carrier, tracking_no: tracking, ship_date: ship_date)
      else
        order.ship!(tracking, ship_date, shipping_carrier: carrier)
        OrderLine.joins(:item)
          .where(order_id: order.id, items: { manufacturer_id: @manufacturer.id })
          .update_all(shipping_carrier: carrier, tracking_no: tracking, ship_date: ship_date)
      end
      ok_count += 1
    end

    if errors.any?
      flash[:alert] = t("shipping_requests.import.partial_success", ok: ok_count, ng: errors.size)
      flash[:import_errors] = errors
    else
      flash[:notice] = t("shipping_requests.import.success", count: ok_count)
    end
    redirect_to shipping_request_path(@manufacturer, month: params[:month])
  end

  # 現在の一覧を明細行単位でCSVダウンロード。アイテムごとに運送会社・追跡番号・出荷日を記入してアップロード可能。
  def shipment_template
    authorize @manufacturer, :show?
    parse_date_range_from_params

    order_ids = OrderLine
      .joins(:item)
      .where(items: { manufacturer_id: @manufacturer.id })
      .distinct
      .pluck(:order_id)
    orders_scope = Order
      .where(id: order_ids)
      .by_date_range(@date_from, @date_to)
      .where(shipping_status: %i[confirmed shipped])
    order_ids_in_scope = orders_scope.pluck(:id)
    lines = OrderLine
      .joins(:item, :order)
      .where(order_id: order_ids_in_scope, items: { manufacturer_id: @manufacturer.id })
      .includes(:order, :item)
      .ordered_by_item
      .to_a

    require "csv"
    csv = CSV.generate(headers: true, encoding: "UTF-8") do |out|
      out << %w[発注番号 商品コード 商品名 数量 運送会社 追跡番号 出荷日]
      lines.each do |line|
        order = line.order
        carrier = line.shipping_carrier.to_s.presence || (order.respond_to?(:shipping_carrier) && order.shipping_carrier.to_s.presence) || ""
        tracking = line.tracking_no.to_s.presence || order.tracking_no.to_s.presence || ""
        ship_date = line.ship_date.present? ? line.ship_date.strftime("%Y-%m-%d") : (order.ship_date.present? ? order.ship_date.strftime("%Y-%m-%d") : "")
        out << [order.order_no, line.item&.item_code, line.item&.name, line.quantity, carrier, tracking, ship_date]
      end
    end
    send_data csv.encode(Encoding::UTF_8),
      filename: "発送依頼一覧_#{@manufacturer.code}_#{@date_from.to_s[0..6]}.csv",
      type: "text/csv; charset=utf-8",
      disposition: "attachment"
  end

  def pdf
    authorize @manufacturer
    parse_date_range_from_params

    order_ids = OrderLine
      .joins(:item)
      .where(items: { manufacturer_id: @manufacturer.id })
      .distinct
      .pluck(:order_id)
    orders_scope = Order
      .where(id: order_ids)
      .by_date_range(@date_from, @date_to)
      .where(shipping_status: %i[confirmed shipped])
    order_ids = orders_scope.pluck(:id)

    lines_by_order = OrderLine
      .joins(:item, :order)
      .where(order_id: order_ids, items: { manufacturer_id: @manufacturer.id })
      .includes(:order, :item)
      .ordered_by_item
      .group_by(&:order)

    pdf = ShippingRequestPdfService.new(@manufacturer, lines_by_order, @date_from, @date_to).call
    send_data pdf,
      filename: "shipping_request_#{@manufacturer.code}_#{Date.current.strftime('%Y%m%d')}.pdf",
      type: "application/pdf",
      disposition: "attachment"
  end

  private

  def set_manufacturer
    @manufacturer = policy_scope(Manufacturer).find(params[:manufacturer_id])
  end

  # 請求と揃えて月次で見れるように。month (YYYY-MM) があればその月の1日〜末日、なければ date_from/date_to または今月
  def parse_date_range_from_params
    if params[:month].present?
      d = Date.parse("#{params[:month]}-01")
      @date_from = d.beginning_of_month.to_s
      @date_to = d.end_of_month.to_s
    else
      @date_from = params[:date_from].presence || Date.current.beginning_of_month.to_s
      @date_to = params[:date_to].presence || Date.current.end_of_month.to_s
    end
  end
end
