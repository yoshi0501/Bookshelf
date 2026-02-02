# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Order numbering", type: :model do
  describe "Order number generation" do
    let!(:company) { create(:company, code: "TEST", order_prefix: "ORD", order_seq: 0) }
    let!(:user) { create(:user, :with_profile, company: company, member_status: :active) }
    let!(:customer) { create(:customer, company: company) }

    it "generates sequential order numbers" do
      order1 = create(:order, company: company, customer: customer, ordered_by_user: user)
      order2 = create(:order, company: company, customer: customer, ordered_by_user: user)
      order3 = create(:order, company: company, customer: customer, ordered_by_user: user)

      expect(order1.order_no).to eq("ORD-0000001")
      expect(order2.order_no).to eq("ORD-0000002")
      expect(order3.order_no).to eq("ORD-0000003")
    end

    it "uses company prefix" do
      other_company = create(:company, code: "OTHER", order_prefix: "XYZ", order_seq: 0)
      other_customer = create(:customer, company: other_company)
      other_user = create(:user, :with_profile, company: other_company, member_status: :active)

      order = create(:order, company: other_company, customer: other_customer, ordered_by_user: other_user)
      expect(order.order_no).to start_with("XYZ-")
    end

    it "updates company order_seq after creation" do
      expect { create(:order, company: company, customer: customer, ordered_by_user: user) }
        .to change { company.reload.order_seq }.by(1)
    end

    it "enforces unique order_no per company" do
      order1 = create(:order, company: company, customer: customer, ordered_by_user: user)

      duplicate = company.orders.new(
        customer: customer,
        ordered_by_user: user,
        order_date: Date.current,
        order_no: order1.order_no
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:order_no]).to be_present
    end
  end

  describe "Concurrent order creation (race condition prevention)" do
    let!(:company) { create(:company, code: "RACE", order_prefix: "RC", order_seq: 0) }
    let!(:user) { create(:user, :with_profile, company: company, member_status: :active) }
    let!(:customer) { create(:customer, company: company) }

    it "prevents duplicate order numbers under concurrent creation" do
      order_numbers = []
      errors = []

      # Simulate concurrent order creation
      threads = 10.times.map do
        Thread.new do
          begin
            order = Order.create!(
              company: company,
              customer: customer,
              ordered_by_user: user,
              order_date: Date.current
            )
            order_numbers << order.order_no
          rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
            errors << e.message
          end
        end
      end

      threads.each(&:join)

      # All successful orders should have unique numbers
      expect(order_numbers.uniq.size).to eq(order_numbers.size)

      # Company seq should match number of successful orders
      expect(company.reload.order_seq).to eq(order_numbers.size)
    end

    it "uses row-level locking for sequence increment" do
      # This test verifies that generate_next_order_no! uses with_lock
      expect(company).to receive(:with_lock).and_call_original

      company.generate_next_order_no!
    end
  end

  describe "Order number format" do
    let!(:company) { create(:company, code: "FMT", order_prefix: "ABC", order_seq: 999999) }
    let!(:user) { create(:user, :with_profile, company: company, member_status: :active) }
    let!(:customer) { create(:customer, company: company) }

    it "pads order number to 7 digits" do
      order = create(:order, company: company, customer: customer, ordered_by_user: user)
      expect(order.order_no).to eq("ABC-1000000")
    end

    it "handles numbers larger than 7 digits" do
      company.update!(order_seq: 9999999)
      order = create(:order, company: company, customer: customer, ordered_by_user: user)
      expect(order.order_no).to eq("ABC-10000000")
    end
  end
end
