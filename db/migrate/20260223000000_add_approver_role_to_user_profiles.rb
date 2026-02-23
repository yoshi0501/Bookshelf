# frozen_string_literal: true

class AddApproverRoleToUserProfiles < ActiveRecord::Migration[7.1]
  def up
    # 既存の値をシフト: company_admin (1) -> (2), internal_admin (2) -> (3)
    # その後、approver を 1 に設定できるようにする
    execute <<-SQL
      UPDATE user_profiles SET role = 2 WHERE role = 1;
    SQL
    execute <<-SQL
      UPDATE user_profiles SET role = 3 WHERE role = 2;
    SQL
  end

  def down
    # ロールバック: internal_admin (3) -> (2), company_admin (2) -> (1)
    # approver (1) は normal (0) に戻す
    execute <<-SQL
      UPDATE user_profiles SET role = 0 WHERE role = 1;
    SQL
    execute <<-SQL
      UPDATE user_profiles SET role = 1 WHERE role = 2;
    SQL
    execute <<-SQL
      UPDATE user_profiles SET role = 2 WHERE role = 3;
    SQL
  end
end
