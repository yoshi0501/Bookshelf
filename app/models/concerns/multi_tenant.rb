# frozen_string_literal: true

# Multi-tenant concern for company-scoped models
# CRITICAL: All tenant-scoped queries MUST use this concern
module MultiTenant
  extend ActiveSupport::Concern

  included do
    belongs_to :company

    # Default scope is intentionally NOT used to prevent accidental bypass
    # Instead, use explicit scopes in controllers/policies

    scope :for_company, ->(company) { where(company: company) }
    scope :for_company_id, ->(company_id) { where(company_id: company_id) }

    validates :company_id, presence: true
  end

  class_methods do
    # Safe finder that ensures company scope
    def find_for_company(id, company)
      for_company(company).find(id)
    end

    def find_for_company!(id, company)
      for_company(company).find(id)
    rescue ActiveRecord::RecordNotFound
      raise ActiveRecord::RecordNotFound, "Record not found or access denied"
    end
  end
end
