# frozen_string_literal: true

module Co2EquivalentsHelper
  # CO2削減量（kg）を身近な例えに換算して遊び心のある貢献度を表示
  # 参考: 環境省・各種環境団体の概算値
  EQUIVALENTS = {
    # 1本の木が1年間で吸収するCO2: 約22kg
    trees: { per_kg: 1.0 / 22, unit: :trees, label_key: "trees" },
    # ガソリン車の走行距離: 1L→約2.3kg CO2、燃費10km/Lとして 1kg≈4.35km
    car_km: { per_kg: 4.35, unit: :km, label_key: "car_km" },
    # スマホフル充電: 約0.03kg/回
    smartphone_charges: { per_kg: 1.0 / 0.03, unit: :count, label_key: "smartphone_charges" },
    # エコバッグ使用: レジ袋1枚の製造・廃棄で約0.02kg → 50枚分
    ecobags: { per_kg: 50, unit: :count, label_key: "ecobags" }
  }.freeze

  def co2_equivalents_for_display(co2_kg)
    return [] if co2_kg.blank? || co2_kg.to_f <= 0

    kg = co2_kg.to_f
    EQUIVALENTS.filter_map do |key, config|
      value = (kg * config[:per_kg]).round(1)
      next if value < 0.1

      label = t("dashboard.eco_contribution.equivalents.#{config[:label_key]}")
      formatted = format_equivalent(value, config[:unit])
      { key: key, label: label, value: formatted, raw: value }
    end
  end

  private

  def format_equivalent(value, unit)
    case unit
    when :trees
      value >= 1 ? "#{value.to_i}本" : "約1本"
    when :km
      value >= 1 ? "#{value.to_i}km" : "#{value.round(1)}km"
    when :count
      value >= 1 ? "#{value.to_i}回分" : "約1回分"
    else
      value.to_s
    end
  end
end
