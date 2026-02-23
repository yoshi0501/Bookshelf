# frozen_string_literal: true

# 請求書PDFに印字する「当社」情報（1件のみ・全PDF共通）
class IssuerSetting < ApplicationRecord
  # シングルトン: 常に1レコードのみ
  class << self
    def current
      first || create!(name: "")
    end
  end

  def full_address
    [postal_code, prefecture, city, address1, address2].compact_blank.join(" ")
  end
end
