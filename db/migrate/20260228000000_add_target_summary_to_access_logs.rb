# frozen_string_literal: true

class AddTargetSummaryToAccessLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :access_logs, :target_summary, :string, limit: 255
  end
end
