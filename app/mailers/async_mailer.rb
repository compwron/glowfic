class AsyncMailer < ApplicationMailer
  include Resque::Mailer

  default from: "Glowfic Constellation <#{ENV.fetch('GMAIL_USERNAME', nil)}>"
  helper :application
  helper :mailer
  layout 'mailer'
end
