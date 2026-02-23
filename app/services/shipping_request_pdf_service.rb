# frozen_string_literal: true

# メーカー宛て発送依頼PDF（発注番号・納品先・明細をメーカー別に出力）
class ShippingRequestPdfService
  require "prawn"
  require "prawn/table"

  def initialize(manufacturer, lines_by_order, date_from, date_to)
    @manufacturer = manufacturer
    @lines_by_order = lines_by_order
    @date_from = date_from
    @date_to = date_to
  end

  def call
    pdf = Prawn::Document.new(page_size: "A4", page_layout: :portrait, margin: [40, 40, 40, 40])
    setup_japanese_font(pdf)
    pdf.font "Japanese" if @japanese_font_available

    # タイトル・宛先
    japanese_text(pdf, "発送依頼", size: 18, style: :bold, align: :center)
    pdf.move_down 8
    japanese_text(pdf, "#{@manufacturer.name} 御中", size: 12, style: :bold)
    japanese_text(pdf, "対象期間: #{@date_from} 〜 #{@date_to}", size: 10)
    pdf.move_down 20

    @lines_by_order.each do |order, lines|
      next if lines.blank?

      # 発注ブロック
      pdf.font "Japanese" if @japanese_font_available
      japanese_text(pdf, "【#{order.order_no}】 #{order.order_date.strftime("%Y/%m/%d")}", size: 11, style: :bold)
      pdf.move_down 4
      addr = [order.ship_postal_code, order.ship_prefecture, order.ship_city, order.ship_address1, order.ship_address2].compact_blank.join(" ")
      japanese_text(pdf, "納品先: #{addr.presence || "-"}", size: 9)
      pdf.move_down 8

      # 明細テーブル
      data = [[utf8("商品コード"), utf8("商品名"), utf8("数量")]]
      lines.each do |line|
        data << [
          utf8(line.item&.item_code || "-"),
          utf8(line.item&.name || "-"),
          line.quantity.to_s
        ]
      end
      cell_style = { size: 9, padding: 3 }
      cell_style[:font] = "Japanese" if @japanese_font_available
      pdf.table(data, header: true, width: pdf.bounds.width, cell_style: cell_style) do |t|
        t.row(0).font_style = :bold
        t.row(0).background_color = "E0E0E0"
        t.cells.font = "Japanese" if @japanese_font_available
        t.column(2).style = { align: :right }
      end
      pdf.move_down 18
    end

    pdf.render
  end

  private

  def setup_japanese_font(pdf)
    @japanese_font_available = false
    fonts_dir = Rails.root.join("app/assets/fonts")
    %w[NotoSansCJKjp-Regular.ttf NotoSansCJKjp-Regular.otf IPAexGothic.ttf].each do |name|
      ttf_path = fonts_dir.join(name).to_s
      next unless File.exist?(ttf_path)
      begin
        pdf.font_families.update("Japanese" => { normal: ttf_path, bold: ttf_path })
        pdf.font "Japanese"
        @japanese_font_available = true
        return
      rescue => e
        Rails.logger.error("ShippingRequestPdfService font #{name}: #{e.message}") if defined?(Rails)
      end
    end
    pdf.font "Helvetica"
  end

  def utf8(text)
    return "" if text.nil?
    str = text.to_s
    return str if str.encoding == Encoding::UTF_8 && str.valid_encoding?
    str.encode("UTF-8", invalid: :replace, undef: :replace)
  rescue
    text.to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
  end

  def japanese_text(pdf, text, options = {})
    t = utf8(text)
    return if t.empty?
    if @japanese_font_available
      pdf.font("Japanese") { pdf.text t, options }
    else
      pdf.text t, options
    end
  end
end
