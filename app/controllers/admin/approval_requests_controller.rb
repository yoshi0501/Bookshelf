# frozen_string_literal: true

module Admin
  class ApprovalRequestsController < ApplicationController
    before_action :set_approval_request, only: %i[show approve reject]

    def index
      @pagy, @approval_requests = pagy(
        policy_scope(ApprovalRequest)
          .includes(user_profile: :user)
          .recent
      )
    end

    def show
      authorize @approval_request
    end

    def approve
      authorize @approval_request

      if @approval_request.approve!(current_user)
        redirect_to admin_approval_requests_path, notice: t("approval_requests.approved")
      else
        redirect_to admin_approval_request_path(@approval_request),
          alert: t("approval_requests.approve_failed")
      end
    end

    def reject
      authorize @approval_request

      if @approval_request.reject!(current_user, params[:comment])
        redirect_to admin_approval_requests_path, notice: t("approval_requests.rejected")
      else
        redirect_to admin_approval_request_path(@approval_request),
          alert: t("approval_requests.reject_failed")
      end
    end

    private

    def set_approval_request
      @approval_request = policy_scope(ApprovalRequest).find(params[:id])
    end
  end
end
