# frozen_string_literal: true

# PaperTrail configuration for audit trail
PaperTrail.config.enabled = true
PaperTrail.config.has_paper_trail_defaults = {
  on: %i[create update destroy]
}

# Use JSONB for PostgreSQL
PaperTrail.config.serializer = PaperTrail::Serializers::JSON
