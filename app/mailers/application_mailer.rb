class ApplicationMailer < ActionMailer::Base
  default from: 'noreply@example.com'
  layout 'mailer'
  
  def default_url_options
    Rails.application.config.action_mailer.default_url_options || { host: 'localhost:3000' }
  end
end
