# frozen_string_literal: true

# センターごとの明細書PDF（指定月の当該センターの発注明細）
class StatementGenerator
  require 'prawn'
  require 'prawn/table'
  include ActionView::Helpers::NumberHelper

  TAX_RATE = 0.10

  def initialize(customer, year, month)
    @customer = customer
    @year = year.to_i
    @month = month.to_i
    @start_date = Date.new(@year, @month, 1)
    @end_date = @start_date.end_of_month
  end

  def generate
    customer_ids = if @customer.is_billing_center?
      @customer.customers.active.pluck(:id) + [@customer.id]
    else
      [@customer.id]
    end

    orders = Order
      .where(customer_id: customer_ids)
      .where(order_date: @start_date..@end_date)
      .where(shipping_status: %i[shipped delivered])
      .includes(:customer, :company, order_lines: :item)
      .order(:order_date, :order_no)

    return nil if orders.empty?

    @total_amount = orders.sum(&:total_amount)
    @tax_amount = (@total_amount * TAX_RATE).to_i
    @total_with_tax = @total_amount + @tax_amount

    pdf = Prawn::Document.new(page_size: 'A4', page_layout: :portrait, margin: [40, 40, 40, 40])
    setup_japanese_font(pdf)
    pdf.font 'Japanese' if @japanese_font_available

    # タイトル
    pdf.text utf8_text(I18n.t('customers.statement.title')), size: 20, style: :bold, align: :center
    pdf.move_down 10

    # 対象（請求先のときは請求先名、受注のみのときはそのセンター名）
    pdf.font 'Japanese' if @japanese_font_available
    if @customer.is_billing_center?
      pdf.text "#{I18n.t('customers.statement.target_billing_center')} #{@customer.center_name}（#{@customer.center_code}）", size: 11, style: :bold
    else
      pdf.text "#{I18n.t('customers.statement.target_center')} #{@customer.center_name}（#{@customer.center_code}）", size: 11, style: :bold
    end
    pdf.text "#{I18n.t('customers.statement.period')} #{@year}#{I18n.t('customers.statement.year')}#{@month}#{I18n.t('customers.statement.month')}", size: 10
    pdf.move_down 15

    # センターごとにブロック分けして明細を表示（customer_id でグループ化して確実に分ける）
    center_ids = orders.map(&:customer_id).uniq
    centers_ordered = Customer.where(id: center_ids).order(:center_code).to_a

    centers_ordered.each do |center|
      center_orders = orders.select { |o| o.customer_id == center.id }
      next if center_orders.empty?

      # センター見出し（シンプルにセンター名のみ）
      pdf.font 'Japanese' if @japanese_font_available
      japanese_text(pdf, center.center_name, size: 12, style: :bold)
      pdf.move_down 8

      # このセンターの明細（発注日・会社・品名・数量・単位・単価・金額・消費税）
      draw_order_table(pdf, center_orders)

      # このセンターの小計
      center_amount = center_orders.sum(&:total_amount)
      center_tax = (center_amount * TAX_RATE).to_i
      pdf.bounding_box([pdf.bounds.width - 240, pdf.cursor], width: 240) do
        pdf.font 'Japanese' if @japanese_font_available
        japanese_text(pdf, "#{I18n.t('customers.statement.subtotal')} ¥#{format_number(center_amount)}（#{I18n.t('customers.statement.tax')} ¥#{format_number(center_tax)}）", size: 9, align: :right)
      end
      pdf.move_down 18
    end

    # 合計
    pdf.move_down 5
    pdf.stroke_horizontal_rule
    pdf.move_down 10
    pdf.text "#{I18n.t('customers.statement.total_ex_tax')} ¥#{format_number(@total_amount)}", size: 10, align: :right
    pdf.text "#{I18n.t('customers.statement.tax')} ¥#{format_number(@tax_amount)}", size: 10, align: :right
    pdf.text "#{I18n.t('customers.statement.total_with_tax')} ¥#{format_number(@total_with_tax)}", size: 12, style: :bold, align: :right

    pdf
  end

  private

  def setup_japanese_font(pdf)
    @japanese_font_available = false
    fonts_dir = Rails.root.join('app/assets/fonts')
    %w[NotoSansCJKjp-Regular.ttf NotoSansCJKjp-Regular.otf IPAexGothic.ttf].each do |name|
      ttf_path = fonts_dir.join(name).to_s
      next unless File.exist?(ttf_path)
      begin
        pdf.font_families.update('Japanese' => { normal: ttf_path, bold: ttf_path })
        pdf.font 'Japanese'
        @japanese_font_available = true
        return
      rescue => e
        Rails.logger.error("StatementGenerator font #{name}: #{e.message}") if defined?(Rails)
      end
    end
    if RUBY_PLATFORM.include?('darwin')
      font_path = '/System/Library/Fonts/AppleSDGothicNeo.ttc'
      if File.exist?(font_path)
        begin
          pdf.font_families.update('Japanese' => { normal: { file: font_path, font: 0 }, bold: { file: font_path, font: 0 } })
          pdf.font 'Japanese'
          @japanese_font_available = true
        rescue
          pdf.font 'Helvetica'
        end
      else
        pdf.font 'Helvetica'
      end
    else
      pdf.font 'Helvetica'
    end
  end

  def utf8_text(text)
    return '' if text.nil?
    str = text.to_s
    return str if str.encoding == Encoding::UTF_8 && str.valid_encoding?
    str.encode('UTF-8', invalid: :replace, undef: :replace)
  rescue
    text.to_s.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
  end

  def japanese_text(pdf, text, options = {})
    t = utf8_text(text)
    return if t.empty?
    if @japanese_font_available
      pdf.font('Japanese') { pdf.text t, options }
    else
      pdf.text t, options
    end
  end

  def draw_order_table(pdf, orders)
    # ヘッダー: 発注日・会社・品名・数量・単位・単価・金額・消費税
    data = [[
      utf8_text(I18n.t('customers.statement.table.order_date')),
      utf8_text(I18n.t('customers.statement.table.company')),
      utf8_text(I18n.t('customers.statement.table.item_name')),
      utf8_text(I18n.t('customers.statement.table.quantity')),
      utf8_text(I18n.t('customers.statement.table.unit')),
      utf8_text(I18n.t('customers.statement.table.unit_price')),
      utf8_text(I18n.t('customers.statement.table.amount')),
      utf8_text(I18n.t('customers.statement.table.tax'))
    ]]

    orders.each do |order|
      company_name = order.company&.name || ''
      order.order_lines.each do |line|
        tax = (line.amount * TAX_RATE).to_i
        data << [
          order.order_date.strftime('%Y/%m/%d'),
          utf8_text(company_name),
          utf8_text(line.item&.name || I18n.t('customers.invoice.table.deleted_item')),
          line.quantity.to_s,
          utf8_text('個'),
          utf8_text("¥#{format_number(line.unit_price_snapshot)}"),
          utf8_text("¥#{format_number(line.amount)}"),
          utf8_text("¥#{format_number(tax)}")
        ]
      end
    end

    cell_style = { size: 9, padding: 3 }
    cell_style[:font] = 'Japanese' if @japanese_font_available

    pdf.table(data, header: true, width: pdf.bounds.width, cell_style: cell_style) do |table|
      table.row(0).font_style = :bold
      table.row(0).background_color = 'E0E0E0'
      table.cells.font = 'Japanese' if @japanese_font_available
      [3, 5, 6, 7].each { |i| table.column(i).style = { align: :right } }
    end
  end

  def format_number(number)
    number.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end
end
