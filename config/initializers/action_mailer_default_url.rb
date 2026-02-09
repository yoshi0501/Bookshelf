# frozen_string_literal: true

# メール内リンク（Devise 確認メール等）で必要。未設定だと "Missing host to link to!" になる
Rails.application.config.after_initialize do
  opts = Rails.application.config.action_mailer.default_url_options
  next if opts.is_a?(Hash) && opts[:host].present?

  Rails.application.config.action_mailer.default_url_options =
    if Rails.env.development?
      { host: "localhost", port: 3000, protocol: "http" }
    elsif Rails.env.test?
      { host: "www.example.com" }
    else
      { host: ENV.fetch("MAILER_HOST", "localhost"), protocol: ENV.fetch("MAILER_PROTOCOL", "https") }
    end
end
