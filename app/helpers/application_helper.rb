# frozen_string_literal: true

module ApplicationHelper
  include Pagy::Frontend
  include Co2EquivalentsHelper

  # ダッシュボードの表示条件（会社・センター・月）を引き継いだクエリパラメータ
  def dashboard_filter_params(overrides = {})
    {
      company_id: params[:company_id],
      center_id: params[:center_id],
      month: params[:month]
    }.compact.merge(overrides.compact)
  end

  # ダッシュボードの表示センター選択用オプション（会社選択時のみ使用）
  def center_options_for_dashboard(centers = nil)
    list = centers.to_a
    options = [ [t("dashboard.all_centers"), "" ] ]
    options + list.map { |c| [ "#{c.center_code}: #{c.center_name}", c.id ] }
  end

  # ダッシュボードの月選択用オプション（過去24ヶ月＋未来1ヶ月）
  def month_options_for_dashboard
    today = Date.current
    start_month = today - 24.months
    end_month = today + 1.month
    months = []
    d = start_month.beginning_of_month
    while d <= end_month
      months << [d.strftime("%Y年%m月"), d.strftime("%Y-%m")]
      d = d + 1.month
    end
    months.reverse
  end

  # 発注一覧のソート用リンク（検索・フィルタ・mine を維持）
  def orders_sort_link(column, label)
    current_dir = params[:sort] == column ? params[:direction] : nil
    next_dir = current_dir == "asc" ? "desc" : "asc"
    q = {
      order_no: params[:order_no],
      status: params[:status],
      date_from: params[:date_from],
      date_to: params[:date_to],
      mine: params[:mine],
      sort: column,
      direction: next_dir
    }.compact
    icon_class = if params[:sort] == column
      params[:direction] == "asc" ? "bi-arrow-up-short" : "bi-arrow-down-short"
    else
      "bi-arrow-down-up"
    end
    active = params[:sort] == column
    link_class = "sortable-th-link d-inline-flex align-items-center gap-1 text-decoration-none #{active ? 'text-primary fw-semibold' : 'text-body'}"
    icon = content_tag(:i, "", class: "bi #{icon_class} sortable-th-icon", aria: { hidden: "true" })
    link_to(orders_path(q), class: link_class, data: { turbo: false }) do
      safe_join([ label, icon ], " ")
    end
  end

  # センター一覧のソート用リンク（company_id, type, sort, direction を維持）
  # selected_company_id: ビューで @selected_company&.id を渡すと、URLに company_id が無い場合でもリンクに含める
  def customers_sort_link(column, label, selected_company_id = nil)
    current_dir = params[:sort] == column ? params[:direction] : nil
    next_dir = current_dir == "asc" ? "desc" : "asc"
    company_id = params[:company_id].presence || selected_company_id
    q = { company_id: company_id, type: params[:type], sort: column, direction: next_dir }.compact

    icon_class = if params[:sort] == column
      params[:direction] == "asc" ? "bi-arrow-up-short" : "bi-arrow-down-short"
    else
      "bi-arrow-down-up"
    end
    active = params[:sort] == column
    link_class = "sortable-th-link d-inline-flex align-items-center gap-1 text-decoration-none #{active ? 'text-primary fw-semibold' : 'text-body'}"
    icon = content_tag(:i, "", class: "bi #{icon_class} sortable-th-icon", aria: { hidden: "true" })
    link_to(customers_path(q), class: link_class, data: { turbo: false }) do
      safe_join([ label, icon ], " ")
    end
  end

  # 日付を「2026年1月31日（金）」形式で表示（月・日はゼロ埋めなし）
  def format_date_with_weekday(date)
    wd = %w[日 月 火 水 木 金 土][date.wday]
    "#{date.year}年#{date.month}月#{date.day}日（#{wd}）"
  end

  def page_title(title = nil)
    base_title = "B2B Order System"
    title.present? ? "#{title} | #{base_title}" : base_title
  end

  def flash_class(type)
    case type.to_sym
    when :notice, :success
      "bg-green-50 text-green-800"
    when :alert, :error
      "bg-red-50 text-red-800"
    when :warning
      "bg-yellow-50 text-yellow-800"
    else
      "bg-blue-50 text-blue-800"
    end
  end

  # 運送会社名と追跡番号から追跡URLを返す（trackings.jp 経由）。該当しなければ nil。
  # 伝票番号は数字のみ使用（ハイフン等は除去）。
  def tracking_url_for(carrier_name, tracking_no)
    return nil if tracking_no.blank?
    id = tracking_carrier_id(carrier_name.to_s.strip)
    return nil if id.blank?
    number = tracking_no.to_s.gsub(/\D/, "")
    return nil if number.blank?
    "https://trackings.jp/toi/#{ERB::Util.url_encode(id)}/#{ERB::Util.url_encode(number)}"
  end

  # 運送会社名（自由入力）を trackings.jp の運送会社IDに変換
  def tracking_carrier_id(carrier_name)
    return nil if carrier_name.blank?
    key = carrier_name.tr("Ａ-Ｚａ-ｚ", "A-Za-z").downcase
    key_ja = carrier_name
    [
      ["yamato", %w[ヤマト 黒猫 宅急便 クール]],
      ["sagawa", %w[佐川]],
      ["yupack", %w[ゆうパック 日本郵便 郵便 yuupack]],
      ["fukutsu", %w[福山通運 福山]],
      ["seino", %w[西濃]],
      ["nittsu", %w[日通 日本通運]],
      ["tonami", %w[トナミ]],
      ["meitetsuunyu", %w[名鉄運輸 名鉄]],
      ["kintetsu", %w[近鉄]]
    ].each do |id, keywords|
      return id if keywords.any? { |k| key.include?(k) || key_ja.include?(k) }
    end
    nil
  end
end
