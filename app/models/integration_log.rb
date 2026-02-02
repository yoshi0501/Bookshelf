# frozen_string_literal: true

class IntegrationLog < ApplicationRecord
  include MultiTenant

  # Constants
  INTEGRATION_TYPES = %w[csv_export api_sync webhook external_system].freeze
  RESULTS = %w[success failure pending].freeze

  # Associations
  belongs_to :order, optional: true

  # Validations
  validates :integration_type, presence: true, inclusion: { in: INTEGRATION_TYPES }
  validates :result, presence: true, inclusion: { in: RESULTS }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(integration_type: type) }
  scope :failures, -> { where(result: "failure") }
  scope :successes, -> { where(result: "success") }

  # Class methods
  def self.log_success(company:, type:, order: nil, payload: nil)
    create!(
      company: company,
      order: order,
      integration_type: type,
      result: "success",
      payload: payload&.to_json
    )
  end

  def self.log_failure(company:, type:, error:, order: nil, payload: nil)
    create!(
      company: company,
      order: order,
      integration_type: type,
      result: "failure",
      error_message: error,
      payload: payload&.to_json
    )
  end

  # Instance methods
  def success?
    result == "success"
  end

  def failure?
    result == "failure"
  end

  def parsed_payload
    return nil if payload.blank?
    JSON.parse(payload)
  rescue JSON::ParserError
    payload
  end
end
