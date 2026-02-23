# frozen_string_literal: true

class OrderApprovalRequestsController < ApplicationController
  before_action :set_order_approval_request, only: %i[show approve reject]

  def index
    scope = policy_scope(OrderApprovalRequest)
      .includes(order: [:customer, :ordered_by_user])
      .order(:status, created_at: :desc) # 承認待ち(status=0)を先頭に
    @pending_count = scope.status_pending.count
    @pagy, @order_approval_requests = pagy(scope)
  end

  def show
    authorize @order_approval_request
    @order = @order_approval_request.order
  end

  def approve
    authorize @order_approval_request

    if @order_approval_request.approve!(current_user)
      # 承認完了メールを送信
      OrderMailer.approval_confirmed(@order_approval_request.order, current_user).deliver_later
      
      redirect_to order_approval_requests_path, notice: "発注が承認されました"
    else
      redirect_to order_approval_request_path(@order_approval_request),
        alert: "承認に失敗しました"
    end
  end

  def reject
    authorize @order_approval_request

    if @order_approval_request.reject!(current_user, params[:comment])
      # 却下メールを送信
      OrderMailer.approval_rejected(@order_approval_request.order, current_user, params[:comment]).deliver_later
      
      redirect_to order_approval_requests_path, notice: "発注が却下されました"
    else
      redirect_to order_approval_request_path(@order_approval_request),
        alert: "却下に失敗しました"
    end
  end

  private

  def set_order_approval_request
    @order_approval_request = policy_scope(OrderApprovalRequest).find(params[:id])
  end
end
