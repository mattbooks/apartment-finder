#encoding: utf-8
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

ARGF.each do |dir|
  dir = dir.chomp
  title = File.open("#{dir}/title", &:read).chomp
  description = File.open("#{dir}/description", &:read).chomp

  # images = Dir.glob("#{dir}/images/*")

  Mail.deliver do
    to(to_addr)
    from(from_addr)
    subject(title.force_encoding('utf-8'))

    html_part do
      content_type('text/html; charset=UTF-8')
      body(description).force_encoding('utf-8')
    end

    # images.each do |image|
    #   begin
    #     add_file({
    #       filename: File.basename(image),
    #       content: File.read(image, encoding: "BINARY")
    #     })
    #   rescue
    #     STDERR.puts "Failed to add image"
    #   end
    # end
  end
end
