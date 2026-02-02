require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Bookshelf
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Use Rails 7.1 cache format version (default for Rails 7.1)
    config.active_support.cache_format_version = 7.1

    # Add app/lib to autoload paths
    config.autoload_paths << Rails.root.join("app", "lib")

    # Set default locale to Japanese
    config.i18n.default_locale = :ja
    config.i18n.available_locales = [:ja, :en]
  end
end
