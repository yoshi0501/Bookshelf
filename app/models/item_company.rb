# frozen_string_literal: true

class ItemCompany < ApplicationRecord
  # Associations
  belongs_to :item
  belongs_to :company

  # Validations
  validates :item_id, uniqueness: { scope: :company_id }
end
