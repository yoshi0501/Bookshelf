# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Multi-tenant data isolation", type: :model do
  let!(:company_a) { create(:company, code: "COMPA", order_prefix: "ORDA") }
  let!(:company_b) { create(:company, code: "COMPB", order_prefix: "ORDB") }

  let!(:user_a) { create(:user, :with_profile, company: company_a, role: :normal, member_status: :active) }
  let!(:user_b) { create(:user, :with_profile, company: company_b, role: :normal, member_status: :active) }

  let!(:customer_a) { create(:customer, company: company_a) }
  let!(:customer_b) { create(:customer, company: company_b) }

  let!(:item_a) { create(:item, company: company_a) }
  let!(:item_b) { create(:item, company: company_b) }

  let!(:order_a) { create(:order, company: company_a, customer: customer_a, ordered_by_user: user_a) }
  let!(:order_b) { create(:order, company: company_b, customer: customer_b, ordered_by_user: user_b) }

  describe "Customer model" do
    it "scopes customers to company" do
      expect(Customer.for_company(company_a)).to include(customer_a)
      expect(Customer.for_company(company_a)).not_to include(customer_b)
    end

    it "prevents accessing other company's customers via find_for_company" do
      expect(Customer.find_for_company(customer_a.id, company_a)).to eq(customer_a)
      expect { Customer.find_for_company!(customer_b.id, company_a) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "Item model" do
    it "scopes items to company" do
      expect(Item.for_company(company_a)).to include(item_a)
      expect(Item.for_company(company_a)).not_to include(item_b)
    end

    it "prevents accessing other company's items via find_for_company" do
      expect(Item.find_for_company(item_a.id, company_a)).to eq(item_a)
      expect { Item.find_for_company!(item_b.id, company_a) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "Order model" do
    it "scopes orders to company" do
      expect(Order.for_company(company_a)).to include(order_a)
      expect(Order.for_company(company_a)).not_to include(order_b)
    end

    it "prevents accessing other company's orders via find_for_company" do
      expect(Order.find_for_company(order_a.id, company_a)).to eq(order_a)
      expect { Order.find_for_company!(order_b.id, company_a) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end

    it "validates customer belongs to same company" do
      order = Order.new(
        company: company_a,
        customer: customer_b,
        ordered_by_user: user_a,
        order_date: Date.current
      )
      expect(order).not_to be_valid
      expect(order.errors[:customer]).to include("must belong to the same company")
    end
  end

  describe "OrderLine model" do
    let!(:order_line_a) { create(:order_line, order: order_a, item: item_a, company: company_a) }

    it "scopes order lines to company" do
      expect(OrderLine.for_company(company_a)).to include(order_line_a)
    end

    it "validates item belongs to same company" do
      line = OrderLine.new(
        company: company_a,
        order: order_a,
        item: item_b,
        quantity: 1
      )
      expect(line).not_to be_valid
      expect(line.errors[:item]).to include("must belong to the same company")
    end
  end

  describe "Policy scopes" do
    describe CustomerPolicy::Scope do
      it "returns only company's customers for normal user" do
        scope = CustomerPolicy::Scope.new(user_a, Customer)
        expect(scope.resolve).to include(customer_a)
        expect(scope.resolve).not_to include(customer_b)
      end

      it "returns all customers for internal admin" do
        admin = create(:user, :with_profile, company: company_a, role: :internal_admin, member_status: :active)
        scope = CustomerPolicy::Scope.new(admin, Customer)
        expect(scope.resolve).to include(customer_a)
        expect(scope.resolve).to include(customer_b)
      end

      it "returns nothing for pending user" do
        pending_user = create(:user, :with_profile, company: company_a, role: :normal, member_status: :pending)
        scope = CustomerPolicy::Scope.new(pending_user, Customer)
        expect(scope.resolve).to be_empty
      end
    end

    describe OrderPolicy::Scope do
      it "returns only company's orders for normal user" do
        scope = OrderPolicy::Scope.new(user_a, Order)
        expect(scope.resolve).to include(order_a)
        expect(scope.resolve).not_to include(order_b)
      end
    end

    describe ItemPolicy::Scope do
      it "returns only company's items for normal user" do
        scope = ItemPolicy::Scope.new(user_a, Item)
        expect(scope.resolve).to include(item_a)
        expect(scope.resolve).not_to include(item_b)
      end
    end
  end

  describe "Cross-company data access prevention" do
    it "prevents creating order with customer from different company" do
      expect {
        Order.create!(
          company: company_a,
          customer: customer_b,
          ordered_by_user: user_a,
          order_date: Date.current
        )
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "prevents creating order line with item from different company" do
      expect {
        OrderLine.create!(
          company: company_a,
          order: order_a,
          item: item_b,
          quantity: 1
        )
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
