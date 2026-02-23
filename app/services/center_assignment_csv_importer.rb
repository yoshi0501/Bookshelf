# frozen_string_literal: true

# センターへの承認者・メンバー所属をCSVで一括更新する。
# CSV: center_code, approver_email, member_emails（member_emails はカンマ区切り、任意）
# 異動時の一括変更に利用する。
class CenterAssignmentCsvImporter
  attr_reader :company, :errors, :updated_centers, :updated_members

  def initialize(company)
    @company = company
    @errors = []
    @updated_centers = 0
    @updated_members = 0
  end

  def run(csv_content)
    @errors = []
    @updated_centers = 0
    @updated_members = 0
    rows = parse_csv(csv_content)
    return false if rows.nil?

    rows.each_with_index do |row, idx|
      process_row(row, idx + 2) # 1-based + header
    end
    @errors.empty?
  end

  private

  def parse_csv(content)
    require "csv"
    csv = CSV.parse(content.force_encoding("UTF-8"), headers: true, encoding: "UTF-8")
    unless csv.headers&.include?("center_code")
      @errors << I18n.t("customers.import_assignments.missing_center_code")
      return nil
    end
    csv
  rescue ArgumentError, CSV::MalformedCSVError => e
    @errors << I18n.t("customers.import_assignments.invalid_csv", message: e.message)
    nil
  end

  def process_row(row, line_no)
    center_code = row["center_code"]&.strip
    approver_email = row["approver_email"]&.strip
    member_emails_str = row["member_emails"]&.strip

    if center_code.blank?
      @errors << I18n.t("customers.import_assignments.blank_center_code", line: line_no)
      return
    end

    center = Customer.for_company(company).billing_centers.find_by(center_code: center_code)
    unless center
      @errors << I18n.t("customers.import_assignments.center_not_found", line: line_no, code: center_code)
      return
    end

    # 承認者を更新
    if approver_email.present?
      approver = UserProfile.for_company(company).joins(:user).find_by(users: { email: approver_email })
      unless approver
        @errors << I18n.t("customers.import_assignments.approver_not_found", line: line_no, email: approver_email)
      elsif center.approver_user_profile_id != approver.id
        center.update!(approver_user_profile_id: approver.id)
        @updated_centers += 1
      end
    else
      if center.approver_user_profile_id.present?
        center.update!(approver_user_profile_id: nil)
        @updated_centers += 1
      end
    end

    # メンバー所属を更新（該当センターにまとめて紐付け）
    if member_emails_str.present?
      member_emails = member_emails_str.split(/[,，\s]+/).map(&:strip).reject(&:blank?)
      member_emails.each do |email|
        profile = UserProfile.for_company(company).joins(:user).find_by(users: { email: email })
        unless profile
          @errors << I18n.t("customers.import_assignments.member_not_found", line: line_no, email: email)
          next
        end
        profile.update!(billing_center_id: center.id)
        @updated_members += 1
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    @errors << I18n.t("customers.import_assignments.validation_error", line: line_no, message: e.message)
  end
end
