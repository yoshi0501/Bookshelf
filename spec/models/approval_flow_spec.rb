# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Approval flow", type: :model do
  let!(:company) { create(:company, :with_domain, domain: "test-company.com") }
  let!(:admin_user) do
    create(:user, :with_profile,
      company: company,
      role: :company_admin,
      member_status: :active,
      email: "admin@test-company.com"
    )
  end

  describe "User signup with matching domain" do
    it "creates user_profile with pending status when email domain matches" do
      user = User.create!(
        email: "newuser@test-company.com",
        password: "password123456",
        password_confirmation: "password123456"
      )

      expect(user.user_profile).to be_present
      expect(user.user_profile.company).to eq(company)
      expect(user.user_profile.member_status).to eq("pending")
    end

    it "creates approval_request for pending user" do
      user = User.create!(
        email: "newuser2@test-company.com",
        password: "password123456",
        password_confirmation: "password123456"
      )

      approval_request = ApprovalRequest.find_by(user_profile: user.user_profile)
      expect(approval_request).to be_present
      expect(approval_request.status).to eq("pending")
      expect(approval_request.company).to eq(company)
    end
  end

  describe "User signup without matching domain" do
    it "creates user_profile with unassigned status when email domain does not match" do
      user = User.create!(
        email: "newuser@unknown-domain.com",
        password: "password123456",
        password_confirmation: "password123456"
      )

      expect(user.user_profile).to be_present
      expect(user.user_profile.company).to be_nil
      expect(user.user_profile.member_status).to eq("unassigned")
    end

    it "does not create approval_request for unassigned user" do
      user = User.create!(
        email: "newuser@unknown-domain.com",
        password: "password123456",
        password_confirmation: "password123456"
      )

      approval_request = ApprovalRequest.find_by(user_profile: user.user_profile)
      expect(approval_request).to be_nil
    end
  end

  describe "Approval process" do
    let!(:pending_user) do
      create(:user, :with_profile,
        company: company,
        role: :normal,
        member_status: :pending,
        email: "pending@test-company.com"
      )
    end
    let!(:approval_request) do
      create(:approval_request,
        user_profile: pending_user.user_profile,
        company: company,
        status: :pending
      )
    end

    describe "#approve!" do
      it "changes approval_request status to approved" do
        approval_request.approve!(admin_user)
        expect(approval_request.reload.status).to eq("approved")
      end

      it "changes user_profile member_status to active" do
        approval_request.approve!(admin_user)
        expect(pending_user.user_profile.reload.member_status).to eq("active")
      end

      it "records the reviewer" do
        approval_request.approve!(admin_user)
        expect(approval_request.reload.reviewed_by).to eq(admin_user)
        expect(approval_request.reviewed_at).to be_present
      end
    end

    describe "#reject!" do
      it "changes approval_request status to rejected" do
        approval_request.reject!(admin_user, "Invalid request")
        expect(approval_request.reload.status).to eq("rejected")
      end

      it "changes user_profile member_status to rejected" do
        approval_request.reject!(admin_user, "Invalid request")
        expect(pending_user.user_profile.reload.member_status).to eq("rejected")
      end

      it "records the reviewer and comment" do
        approval_request.reject!(admin_user, "Invalid request")
        expect(approval_request.reload.reviewed_by).to eq(admin_user)
        expect(approval_request.review_comment).to eq("Invalid request")
      end
    end
  end

  describe "User authentication based on status" do
    it "allows active users to authenticate" do
      active_user = create(:user, :with_profile,
        company: company,
        member_status: :active
      )
      expect(active_user.active_for_authentication?).to be true
    end

    it "prevents pending users from authenticating" do
      pending_user = create(:user, :with_profile,
        company: company,
        member_status: :pending
      )
      expect(pending_user.active_for_authentication?).to be false
      expect(pending_user.inactive_message).to eq(:pending_approval)
    end

    it "prevents rejected users from authenticating" do
      rejected_user = create(:user, :with_profile,
        company: company,
        member_status: :rejected
      )
      expect(rejected_user.active_for_authentication?).to be false
      expect(rejected_user.inactive_message).to eq(:account_rejected)
    end
  end

  describe "ApprovalRequestPolicy" do
    let!(:pending_user) do
      create(:user, :with_profile,
        company: company,
        role: :normal,
        member_status: :pending
      )
    end
    let!(:approval_request) do
      create(:approval_request,
        user_profile: pending_user.user_profile,
        company: company,
        status: :pending
      )
    end

    it "allows company_admin to approve requests from same company" do
      policy = ApprovalRequestPolicy.new(admin_user, approval_request)
      expect(policy.approve?).to be true
    end

    it "denies normal users from approving requests" do
      normal_user = create(:user, :with_profile,
        company: company,
        role: :normal,
        member_status: :active
      )
      policy = ApprovalRequestPolicy.new(normal_user, approval_request)
      expect(policy.approve?).to be false
    end

    it "denies company_admin from other company" do
      other_company = create(:company)
      other_admin = create(:user, :with_profile,
        company: other_company,
        role: :company_admin,
        member_status: :active
      )
      policy = ApprovalRequestPolicy.new(other_admin, approval_request)
      expect(policy.approve?).to be false
    end

    it "allows internal_admin to approve any request" do
      internal_admin = create(:user, :with_profile,
        company: company,
        role: :internal_admin,
        member_status: :active
      )
      policy = ApprovalRequestPolicy.new(internal_admin, approval_request)
      expect(policy.approve?).to be true
    end
  end
end
