#encoding: utf-8

FILTER_SIMILAR_IMAGES=true
DEBUG=false

require 'nokogiri'
require 'http'
require 'cgi'
require 'fileutils'
require 'matrix'
require 'tf-idf-similarity'
require 'dhash-vips' if FILTER_SIMILAR_IMAGES

site = ARGV.shift
subsite = ARGV.shift
min_price = ARGV.shift
max_price = ARGV.shift
options = ARGV.shift
target = File.expand_path(ARGV.shift)

raise "Can't find dir '#{target}'" unless Dir.exist?(target)

corpus = Dir.glob("#{target}/*/description").map do |f|
  TfIdfSimilarity::Document.new(File.open(f, &:read).force_encoding('utf-8'))
end

fingerprints = []
if FILTER_SIMILAR_IMAGES
  fingerprints += Dir.glob('#{target}/*/fingerprints/*').
    map { |x| x.split('/')}.
    map(&:last).
    map(&:to_i)
end

url = "http://#{site}.craigslist.org/search/#{subsite}/apa?hasPic=1&bundleDuplicates=1&min_price=#{min_price}&max_price=#{max_price}&#{options}format=rss"

STDERR.puts url

listings = Nokogiri::XML(HTTP.follow.get(url).body.to_s).css('item')

listings.each do |listing|
  link = listing.at_css('link').content
  # title = CGI.unescapeHTML(listing.at_css('title').content)
  html = Nokogiri::HTML(HTTP.follow.get(link).body.to_s)
  images = html.css('img').map do |i|
    i.get_attribute(:src).sub('50x50c', '600x450')
  end

  hood = CGI.unescapeHTML(html.at_css('span.postingtitletext small').content).tr('()', '').downcase
  price = html.at_css('span.postingtitletext span.price').content

  attrs = html.css('div.mapAndAttrs p.attrgroup span').map do |attr|
    CGI.unescapeHTML(attr.content)
  end

  next if attrs.include?('furnished')

  description = html.at_css('section#postingbody').to_html

  id = link.split('/').last.sub('.html', '')
  target_dir = "#{target}/#{id}"
  image_dir = "#{target_dir}/images"
  fingerprint_dir = "#{target_dir}/fingerprints"
  next if Dir.exist?(target_dir)

  FileUtils.mkdir_p(image_dir)
  FileUtils.mkdir_p(fingerprint_dir)

  File.open("#{target_dir}/title", 'w') do |f|
    f.puts "#{hood} - #{price} - #{attrs.join(" / ")}"
  end

  description += "\n<br><br>"
  description += "\n<a href=\"#{link}\">VIEW</a>"
  new_fingerprints = []
  fingerprints_seen = 0

  images.each do |image|
    description += "\n<img src='#{image}'></img>"

    image_path = "#{image_dir}/#{image.split('_')[1]}"
    `curl #{image} 2>/dev/null > #{image_path}`

    if FILTER_SIMILAR_IMAGES
      hash = DHashVips::IDHash.fingerprint image_path
      new_fingerprints << hash
      FileUtils.touch "#{fingerprint_dir}/#{hash}"

      fingerprints.each do |existing|
        if DHashVips::IDHash.distance3(existing, hash) < 15
          fingerprints_seen += 1
          STDERR.puts "SEEN #{image_path} ALREADY" if DEBUG
          break
        end
      end

      fingerprints += new_fingerprints
    end
  end

  File.open("#{target_dir}/description", 'w') do |f|
    f.puts(description)
  end

  corpus << TfIdfSimilarity::Document.new(description)

  model = TfIdfSimilarity::TfIdfModel.new(corpus)

  matrix = model.similarity_matrix

  last_idx = corpus.size - 1

  seen = false
  (0..(last_idx - 1)).to_a.each do |other|
    if matrix[other, last_idx] > 0.85
      seen = true
      break
    end
  end

  STDERR.puts "fp seen: #{fingerprints_seen} images: #{images.size}" if DEBUG

  if fingerprints_seen * 1.0 / images.size > 0.5
    seen = true
  end

  if seen
    STDERR.puts "SKIPPING #{target_dir}" if DEBUG
  else
    puts target_dir
  end
end
