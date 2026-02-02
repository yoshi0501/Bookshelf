# frozen_string_literal: true

module ApplicationHelper
  include Pagy::Frontend

  def page_title(title = nil)
    base_title = "B2B Order System"
    title.present? ? "#{title} | #{base_title}" : base_title
  end

  def flash_class(type)
    case type.to_sym
    when :notice, :success
      "bg-green-50 text-green-800"
    when :alert, :error
      "bg-red-50 text-red-800"
    when :warning
      "bg-yellow-50 text-yellow-800"
    else
      "bg-blue-50 text-blue-800"
    end
  end
end
