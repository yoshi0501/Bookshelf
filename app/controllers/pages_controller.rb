# frozen_string_literal: true

class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]
  skip_before_action :check_member_status, only: [:pending_approval]

  def home
    if user_signed_in?
      if current_user.respond_to?(:manufacturer_user?) && current_user.manufacturer_user?
        redirect_to shipping_requests_path
      else
        redirect_to dashboard_path
      end
    end
  end

  def pending_approval
    unless current_user.user_profile&.pending?
      redirect_to dashboard_path
    end
  end
end
