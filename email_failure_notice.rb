require 'fileutils'
require 'mail'

secret_path = File.expand_path(ARGV.shift)
from_addr = ARGV.shift
to_addr = ARGV.shift.split(',')

raise "Bad secret path #{secret_path}" unless File.exist?(secret_path)

secret = File.open(secret_path, &:read).chomp

options = {
  address: "smtp.gmail.com",
  port: 587,
  domain: 'gmail.com',
  user_name: from_addr,
  password: secret,
  authentication: 'plain',
  enable_starttls_auto: true
}

Mail.defaults do
  delivery_method :smtp, options
end

Mail.deliver do
  to(to_addr)
  from(from_addr)
  subject("Matt the housing thing broke")

  text_part do
    body("Go fix it")
  end
end

