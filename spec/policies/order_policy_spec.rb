# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrderPolicy, type: :policy do
  let(:company_a) { create(:company) }
  let(:company_b) { create(:company) }

  let(:customer_a) { create(:customer, company: company_a) }
  let(:customer_b) { create(:customer, company: company_b) }

  let(:normal_user_a) { create(:user, :with_profile, company: company_a, role: :normal, member_status: :active) }
  let(:normal_user_b) { create(:user, :with_profile, company: company_b, role: :normal, member_status: :active) }
  let(:admin_user_a) { create(:user, :with_profile, company: company_a, role: :company_admin, member_status: :active) }
  let(:internal_admin) { create(:user, :with_profile, company: company_a, role: :internal_admin, member_status: :active) }
  let(:pending_user) { create(:user, :with_profile, company: company_a, role: :normal, member_status: :pending) }

  let(:order_a) { create(:order, company: company_a, customer: customer_a, ordered_by_user: normal_user_a) }
  let(:order_b) { create(:order, company: company_b, customer: customer_b, ordered_by_user: normal_user_b) }

  subject { described_class }

  permissions :show? do
    it "permits active user from same company" do
      expect(subject).to permit(normal_user_a, order_a)
    end

    it "denies active user from different company" do
      expect(subject).not_to permit(normal_user_a, order_b)
    end

    it "permits internal_admin for any order" do
      expect(subject).to permit(internal_admin, order_a)
      expect(subject).to permit(internal_admin, order_b)
    end

    it "denies pending user" do
      expect(subject).not_to permit(pending_user, order_a)
    end
  end

  permissions :create? do
    it "permits active user" do
      expect(subject).to permit(normal_user_a, Order.new)
    end

    it "denies pending user" do
      expect(subject).not_to permit(pending_user, Order.new)
    end
  end

  permissions :update? do
    it "permits active user from same company for draft order" do
      order_a.update!(shipping_status: :draft)
      expect(subject).to permit(normal_user_a, order_a)
    end

    it "permits active user from same company for confirmed order" do
      order_a.update!(shipping_status: :confirmed)
      expect(subject).to permit(normal_user_a, order_a)
    end

    it "denies active user from same company for shipped order" do
      order_a.update!(shipping_status: :shipped)
      expect(subject).not_to permit(normal_user_a, order_a)
    end

    it "denies active user from different company" do
      expect(subject).not_to permit(normal_user_a, order_b)
    end
  end

  permissions :cancel? do
    it "permits for draft order" do
      order_a.update!(shipping_status: :draft)
      expect(subject).to permit(normal_user_a, order_a)
    end

    it "permits for confirmed order" do
      order_a.update!(shipping_status: :confirmed)
      expect(subject).to permit(normal_user_a, order_a)
    end

    it "permits for shipped order" do
      order_a.update!(shipping_status: :shipped)
      expect(subject).to permit(normal_user_a, order_a)
    end

    it "denies for delivered order" do
      order_a.update!(shipping_status: :delivered)
      expect(subject).not_to permit(normal_user_a, order_a)
    end

    it "denies for already cancelled order" do
      order_a.update!(shipping_status: :cancelled)
      expect(subject).not_to permit(normal_user_a, order_a)
    end
  end

  describe "Scope" do
    before do
      order_a
      order_b
    end

    it "returns only same company orders for normal user" do
      scope = Pundit.policy_scope(normal_user_a, Order)
      expect(scope).to include(order_a)
      expect(scope).not_to include(order_b)
    end

    it "returns all orders for internal admin" do
      scope = Pundit.policy_scope(internal_admin, Order)
      expect(scope).to include(order_a)
      expect(scope).to include(order_b)
    end

    it "returns nothing for pending user" do
      scope = Pundit.policy_scope(pending_user, Order)
      expect(scope).to be_empty
    end
  end
end
