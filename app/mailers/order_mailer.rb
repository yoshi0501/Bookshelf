# frozen_string_literal: true

class OrderMailer < ApplicationMailer
  def approval_request(order, admin_users)
    @order = order
    @admin_users = admin_users
    @approval_url = url_for(controller: "order_approval_requests", action: "show", id: order.order_approval_request.id, host: default_url_options[:host] || "localhost:3000")

    mail(
      to: admin_users.map(&:email),
      subject: "発注承認依頼: #{order.order_no}"
    )
  end

  def approval_confirmed(order, approver)
    @order = order
    @approver = approver
    @order_url = url_for(controller: "orders", action: "show", id: order.id, host: default_url_options[:host] || "localhost:3000")

    mail(
      to: order.ordered_by_user.email,
      subject: "発注が承認されました: #{order.order_no}"
    )
  end

  def approval_rejected(order, reviewer, comment = nil)
    @order = order
    @reviewer = reviewer
    @comment = comment
    @order_url = url_for(controller: "orders", action: "show", id: order.id, host: default_url_options[:host] || "localhost:3000")

    mail(
      to: order.ordered_by_user.email,
      subject: "発注が却下されました: #{order.order_no}"
    )
  end
end
