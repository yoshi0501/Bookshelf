# frozen_string_literal: true

namespace :access_logs do
  desc "3ヶ月より古いアクセスログを削除"
  task prune: :environment do
    threshold = 3.months.ago
    deleted = AccessLog.older_than(threshold).delete_all
    puts "Deleted #{deleted} access logs older than #{threshold}"
  end
end
