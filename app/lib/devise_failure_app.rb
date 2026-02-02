# frozen_string_literal: true

class DeviseFailureApp < Devise::FailureApp
  def redirect
    store_location!
    if is_flashing_format?
      flash[:alert] = i18n_message unless flash[:notice]
    end
    redirect_to redirect_url
  end

  def i18n_message
    case warden_message
    when :not_found_in_database
      "Invalid email or password."
    when :invalid
      "Invalid email or password."
    when :invalid_token
      "Invalid email or password."
    when :timeout
      "Your session expired. Please sign in again."
    when :unconfirmed
      "You have to confirm your email address before continuing."
    when :locked
      "Your account is locked."
    when :pending_approval
      "Your account is pending approval."
    when :account_rejected
      "Your account has been rejected."
    when :unassigned_company
      "Your email domain is not associated with any company."
    else
      super
    end
  end
end
