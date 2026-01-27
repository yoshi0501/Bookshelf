# frozen_string_literal: true

# Pagy configuration
Pagy::DEFAULT[:items] = 25
Pagy::DEFAULT[:size]  = [1, 4, 4, 1]

# Enable extras
require "pagy/extras/overflow"
Pagy::DEFAULT[:overflow] = :last_page

require "pagy/extras/metadata"
