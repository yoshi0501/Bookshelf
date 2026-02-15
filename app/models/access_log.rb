# frozen_string_literal: true

# 重要操作のアクセスログ。3ヶ月保持後、rake access_logs:prune で削除。
class AccessLog < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :company, optional: true

  validates :controller_path, :action_name, :request_path, :request_method, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :older_than, ->(date) { where("created_at < ?", date) }

  # 操作の説明用ラベル（日本語）
  def action_label
    key = "#{controller_path.gsub('/', '.')}.#{action_name}"
    I18n.t("access_logs.actions.#{key}", default: "#{controller_path}##{action_name}")
  end
end
