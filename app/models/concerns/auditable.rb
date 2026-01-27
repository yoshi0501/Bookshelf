# frozen_string_literal: true

# PaperTrail audit concern for tracking changes
module Auditable
  extend ActiveSupport::Concern

  included do
    has_paper_trail(
      meta: {
        company_id: ->(record) { record.try(:company_id) },
        request_uuid: ->(record) { PaperTrail.request.controller_info&.dig(:request_uuid) },
        ip_address: ->(record) { PaperTrail.request.controller_info&.dig(:ip_address) },
        user_agent: ->(record) { PaperTrail.request.controller_info&.dig(:user_agent) }
      }
    )
  end
end
