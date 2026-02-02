# frozen_string_literal: true

class DashboardController < ApplicationController
  def index
    @recent_orders = policy_scope(Order).recent.limit(10)
    @pending_approvals_count = if current_user.user_profile.can_approve_members?
      policy_scope(ApprovalRequest).status_pending.count
    else
      0
    end
    @orders_this_month = policy_scope(Order)
      .where(order_date: Date.current.beginning_of_month..Date.current.end_of_month)
      .count
    @total_amount_this_month = policy_scope(Order)
      .where(order_date: Date.current.beginning_of_month..Date.current.end_of_month)
      .sum(:total_amount)

    skip_authorization
  end
end
