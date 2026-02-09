# frozen_string_literal: true

class InvoiceGenerator
  require 'prawn'
  require 'prawn/table'
  include ActionView::Helpers::NumberHelper

  def initialize(billing_center, year, month, receiving_center: nil)
    @billing_center = billing_center
    @receiving_center = receiving_center # 指定時はそのセンター分のみの請求書（センター別請求用）
    @year = year.to_i
    @month = month.to_i
    @start_date = Date.new(@year, @month, 1)
    @end_date = @start_date.end_of_month
  end

  def generate
    # 請求先センターに紐づく受注センターのOrderを取得（receiving_center 指定時はその1センター分のみ）
    if @receiving_center
      all_customer_ids = [@receiving_center.id]
    else
      receiving_centers = @billing_center.customers.active
      receiving_center_ids = receiving_centers.pluck(:id)
      all_customer_ids = receiving_center_ids + [@billing_center.id]
    end

    orders = Order
      .where(customer_id: all_customer_ids)
      .where(order_date: @start_date..@end_date)
      .where(shipping_status: [:shipped, :delivered])
      .includes(:customer, order_lines: :item)
      .order(:order_date, :order_no)

    return nil if orders.empty?

    # データ集計
    @total_amount = orders.sum(&:total_amount)
    @tax_rate = 0.10 # 消費税率10%（必要に応じて変更可能）
    @tax_amount = (@total_amount * @tax_rate).to_i
    @total_with_tax = @total_amount + @tax_amount

    # 品種別集計
    @item_totals = {}
    orders.each do |order|
      order.order_lines.each do |line|
        item_name = line.item&.name || I18n.t('customers.invoice.table.deleted_item', default: '削除された商品')
        @item_totals[item_name] ||= { quantity: 0, amount: 0 }
        @item_totals[item_name][:quantity] += line.quantity
        @item_totals[item_name][:amount] += line.amount
      end
    end

    # PDF生成
    pdf = Prawn::Document.new(page_size: 'A4', page_layout: :portrait, margin: [40, 40, 40, 40])
    
    # フォント設定（日本語対応）- 最初に設定して確実に適用
    setup_japanese_font(pdf)
    
    # 日本語フォントをデフォルトとして設定（すべてのテキスト出力で使用される）
    pdf.font 'Japanese' if @japanese_font_available

    # 上部レイアウト：請求先をトップに、顧客のすぐ下（約20pt空け）に請求書・当社を記載
    top_y = pdf.cursor
    billing_height = 55   # 請求先ブロックの高さ（郵便番号・住所・名前様が収まる程度）
    row2_y = top_y - billing_height - 20  # 請求先のすぐ下に20pt空けて2行目

    # 請求先情報（左上・トップ）。センター別の場合は「対象: 〇〇センター」を追記
    pdf.bounding_box([0, top_y], width: 300, height: billing_height) do
      pdf.font 'Japanese' if @japanese_font_available
      if @billing_center.postal_code.present?
        japanese_text(pdf, "〒#{@billing_center.postal_code}", size: 10)
      end
      if @billing_center.full_address.present?
        japanese_text(pdf, @billing_center.full_address, size: 10)
      end
      pdf.move_down 5
      japanese_text(pdf, "#{@billing_center.center_name}　様", size: 12, style: :bold)
      if @receiving_center
        pdf.move_down 4
        japanese_text(pdf, "#{t_invoice(:target_center, default: '対象')} #{@receiving_center.center_name}（#{@receiving_center.center_code}）", size: 9)
      end
    end
    
    # タイトル（請求先の約20pt下・中央）
    pdf.bounding_box([pdf.bounds.width / 2 - 50, row2_y], width: 100) do
      pdf.font 'Japanese' if @japanese_font_available
      japanese_text(pdf, t_invoice(:title, default: '請求書'), size: 20, style: :bold, align: :center)
    end
    
    # 発行元情報（請求書より少し下・右上）— IssuerSetting を優先、未設定時は請求先の会社（Company）を表示
    issuer = IssuerSetting.current
    company = @billing_center.company
    issuer_y = row2_y - 50  # 請求書タイトルより25pt下
    pdf.bounding_box([pdf.bounds.width - 300, issuer_y], width: 300) do
      pdf.font 'Japanese' if @japanese_font_available
      issuer_name = issuer.name.presence || company&.name
      japanese_text(pdf, issuer_name, size: 12, style: :bold, align: :right) if issuer_name.present?

      issuer_address = issuer.full_address.presence || (company ? [company.postal_code, company.prefecture, company.city, company.address1, company.address2].compact_blank.join(" ") : nil)
      if issuer_address.present?
        issuer_address = "〒#{issuer_address}" if (issuer.postal_code.presence || company&.postal_code).present?
        japanese_text(pdf, issuer_address, size: 10, align: :right)
      end
      phone = issuer.phone.presence || company&.phone
      japanese_text(pdf, "TEL #{phone}", size: 10, align: :right) if phone.present?
      fax = issuer.fax.presence || company&.fax
      japanese_text(pdf, "FAX #{fax}", size: 10, align: :right) if fax.present?
      reg = issuer.registration_number.presence || company&.registration_number
      japanese_text(pdf, "(登録番号：#{reg})", size: 9, align: :right) if reg.present?
    end
    
    # bounding_boxの後はカーソル位置が元に戻るので、適切な位置に移動
    pdf.move_down(30)
    
    # 請求文
    draw_request_text(pdf)
   
     # 振込口座情報
     draw_bank_accounts(pdf)

    # 合計請求額、締日、コード（振込口座の上に記載）
    draw_summary_header(pdf)
    
    # 明細テーブル
    draw_order_table(pdf, orders)
    
    # 品種別合計
    draw_item_subtotals(pdf)
    
    # 消費税合計
    draw_tax_total(pdf)
    
    # 備考欄
    draw_remarks(pdf)
    
    pdf
  end

  private

  def setup_japanese_font(pdf)
    @japanese_font_available = false

    # 1) プロジェクト内の TTF/OTF を優先（文字化けしない）
    fonts_dir = Rails.root.join('app/assets/fonts')
    %w[NotoSansCJKjp-Regular.ttf NotoSansCJKjp-Regular.otf IPAexGothic.ttf].each do |name|
      ttf_path = fonts_dir.join(name).to_s
      next unless File.exist?(ttf_path)

      begin
        pdf.font_families.update(
          'Japanese' => {
            normal: ttf_path,
            bold: ttf_path
          }
        )
        pdf.font 'Japanese'
        @japanese_font_available = true
        return
      rescue => e
        Rails.logger.error("Failed to load bundled Japanese font #{name}: #{e.message}") if defined?(Rails)
      end
    end

    # 2) macOS: TTC は font: 0 で最初のフォントを指定（請求など漢字が正しく出るようにする）
    if RUBY_PLATFORM.include?('darwin')
      font_path = '/System/Library/Fonts/AppleSDGothicNeo.ttc'
      if File.exist?(font_path)
        begin
          pdf.font_families.update(
            'Japanese' => {
              normal: { file: font_path, font: 0 },
              bold: { file: font_path, font: 0 }
            }
          )
          pdf.font 'Japanese'
          @japanese_font_available = true
        rescue => e
          pdf.font 'Helvetica'
          Rails.logger.error("Failed to load Japanese font: #{e.message}") if defined?(Rails)
        end
      else
        pdf.font 'Helvetica'
      end
    else
      pdf.font 'Helvetica'
    end
  end
  
  # テキストをUTF-8に確実にエンコードするヘルパーメソッド
  def utf8_text(text)
    return '' if text.nil?
    str = text.to_s
    # 既にUTF-8の場合はそのまま返す
    return str if str.encoding == Encoding::UTF_8 && str.valid_encoding?
    # UTF-8に変換
    str.encode('UTF-8', invalid: :replace, undef: :replace)
  rescue => e
    # エンコーディング変換に失敗した場合は、強制的にUTF-8に変換
    text.to_s.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
  end
  
  # 翻訳キーがなくても表示されるように default 付きで取得
  def t_invoice(key, default:)
    I18n.t("customers.invoice.#{key}", default: default)
  end

  # 日本語フォントを使用してテキストを出力するヘルパーメソッド
  def japanese_text(pdf, text, options = {})
    text_utf8 = utf8_text(text)
    return if text_utf8.empty?
    
    # 日本語フォントが利用可能な場合は必ず使用
    if @japanese_font_available
      pdf.font('Japanese') do
        pdf.text text_utf8, options
      end
    else
      pdf.text text_utf8, options
    end
  end

  def draw_request_text(pdf)
    japanese_text(pdf, t_invoice(:request_text, default: '下記の通りご請求申し上げます。'), size: 11)
    pdf.move_down 10
  end

  def draw_bank_accounts(pdf)
    issuer = IssuerSetting.current
    company = @billing_center.company
    japanese_text(pdf, t_invoice(:bank_accounts_label, default: '［振込口座］'), size: 10, style: :bold)
    bank1 = issuer.bank_account_1.presence || company&.bank_account_1
    japanese_text(pdf, bank1, size: 10) if bank1.present?
    bank2 = issuer.bank_account_2.presence || company&.bank_account_2
    japanese_text(pdf, bank2, size: 10) if bank2.present?
    pdf.move_down 10
  end

  def draw_summary_header(pdf)
    pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width) do
      pdf.font 'Japanese' if @japanese_font_available
      # 左側：合計請求額
      pdf.bounding_box([0, pdf.cursor], width: 200) do
        pdf.font 'Japanese' if @japanese_font_available
        japanese_text(pdf, t_invoice(:total_billing_amount, default: '合計請求額'), size: 10)
        japanese_text(pdf, "¥#{format_number(@total_with_tax)}", size: 14, style: :bold)
      end
      
      # 右側：締日、コード
      pdf.bounding_box([pdf.bounds.width - 200, pdf.cursor], width: 200) do
        pdf.font 'Japanese' if @japanese_font_available
        japanese_text(pdf, "#{t_invoice(:closing_date_label, default: '締日')} #{@end_date.strftime('%Y/%m/%d')}", size: 10, align: :right)
        japanese_text(pdf, "#{t_invoice(:code_label, default: 'コード')} #{@billing_center.company.code}", size: 10, align: :right)
      end
    end
    pdf.move_down 15
  end

  def draw_previous_billing_info(pdf)
    # 前回請求額等の情報（現在は0で表示、将来的にDBに追加可能）
    pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width) do
      pdf.font 'Japanese' if @japanese_font_available
      japanese_text(pdf, "#{t_invoice(:previous_billing_amount, default: '前回請求額')} #{format_number(0)}", size: 9)
      japanese_text(pdf, "#{t_invoice(:previous_payment_amount, default: '前回入金額')} #{format_number(0)}", size: 9)
      japanese_text(pdf, "#{t_invoice(:adjustment_amount, default: '調整額')} #{format_number(0)}", size: 9)
      japanese_text(pdf, "#{t_invoice(:carryover_amount, default: '繰越額')} #{format_number(0)}", size: 9)
    end
    
    pdf.bounding_box([pdf.bounds.width - 300, pdf.cursor - 40], width: 300) do
      pdf.font 'Japanese' if @japanese_font_available
      japanese_text(pdf, "#{t_invoice(:current_transaction_amount_ex_tax, default: '今回取引額(税抜)')} ¥#{format_number(@total_amount)}", size: 9, align: :right)
      japanese_text(pdf, "#{t_invoice(:consumption_tax, default: '消費税')} ¥#{format_number(@tax_amount)}", size: 9, align: :right)
      japanese_text(pdf, "#{t_invoice(:current_transaction_amount, default: '今回取引額')} ¥#{format_number(@total_with_tax)}", size: 10, style: :bold, align: :right)
    end
    pdf.move_down 15
  end

  def draw_order_table(pdf, orders)
    # 空列をやめて必要な列だけ（月日・品名・数量・単位・単価・金額・消費税・備考）
    data = [[
      utf8_text(I18n.t('customers.invoice.table.order_date', default: '月日')),
      utf8_text(I18n.t('customers.invoice.table.item_name', default: '品名')),
      utf8_text(I18n.t('customers.invoice.table.quantity', default: '数量')),
      utf8_text(I18n.t('customers.invoice.table.unit', default: '単位')),
      utf8_text(I18n.t('customers.invoice.table.unit_price', default: '単価')),
      utf8_text(I18n.t('customers.invoice.table.amount', default: '金額')),
      utf8_text(I18n.t('customers.invoice.table.tax', default: '消費税')),
      utf8_text(I18n.t('customers.invoice.table.remarks', default: '備考'))
    ]]

    orders.each do |order|
      order.order_lines.each_with_index do |line, index|
        row = []
        row << (index == 0 ? order.order_date.strftime('%Y/%m/%d') : '')
        row << utf8_text(line.item&.name || I18n.t('customers.invoice.table.deleted_item', default: '削除された商品'))
        row << line.quantity.to_s
        row << utf8_text('個')
        row << utf8_text("¥#{format_number(line.unit_price_snapshot)}")
        row << utf8_text("¥#{format_number(line.amount)}")
        tax = (line.amount * @tax_rate).to_i
        row << utf8_text("¥#{format_number(tax)}")
        row << ''
        data << row
      end
    end

    cell_style = { size: 8, padding: 4 }
    cell_style[:font] = 'Japanese' if @japanese_font_available

    pdf.table(data, header: true, width: pdf.bounds.width, cell_style: cell_style) do |table|
      table.row(0).font_style = :bold
      table.row(0).background_color = 'E0E0E0'
      table.cells.font = 'Japanese' if @japanese_font_available
      # 右寄せ: 数量(2), 単価(4), 金額(5), 消費税(6)
      [2, 4, 5, 6].each { |i| table.column(i).style = { align: :right } }
      # 左寄せ: 月日(0), 品名(1), 単位(3)
      [0, 1, 3].each { |i| table.column(i).style = { align: :left } }
    end
    pdf.move_down 10
  end

  def draw_item_subtotals(pdf)
    return if @item_totals.empty?
    
    pdf.font 'Japanese' if @japanese_font_available
    japanese_text(pdf, t_invoice(:item_subtotal, default: '品種別合計'), size: 10, style: :bold)
    pdf.move_down 5
    
    @item_totals.each do |item_name, totals|
      pdf.bounding_box([50, pdf.cursor], width: pdf.bounds.width - 50) do
        pdf.font 'Japanese' if @japanese_font_available
        japanese_text(pdf, "#{item_name} #{totals[:quantity]} #{I18n.t('customers.invoice.table.unit', default: '個')} ¥#{format_number(totals[:amount])}", size: 9)
      end
      pdf.move_down 3
    end
    pdf.move_down 10
  end

  def draw_tax_total(pdf)
    pdf.bounding_box([pdf.bounds.width - 200, pdf.cursor], width: 200) do
      pdf.font 'Japanese' if @japanese_font_available
      japanese_text(pdf, "#{t_invoice(:tax_subtotal_label, default: '10％対象')} ¥#{format_number(@total_amount)}", size: 9, align: :right)
      japanese_text(pdf, "¥#{format_number(@tax_amount)}", size: 10, style: :bold, align: :right)
    end
    pdf.move_down 15
  end

  def draw_remarks(pdf)
    japanese_text(pdf, t_invoice(:remarks_label, default: '備考：'), size: 10)
    pdf.move_down 20
  end

  def format_number(number)
    # 小数を整数に変換してからカンマ区切り
    number.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end
end
