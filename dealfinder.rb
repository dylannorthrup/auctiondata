#!/usr/bin/ruby

require 'net/http'
require 'json'
require 'uri'
require 'pp'

# These are the Inscription vendor deals I'm using for MoP
$item_filters = { 
  72234 => { 'name' => "Green Tea Leaf", 'buyout' => 15000 }, 
  72237 => { 'name' => "Rain Poppy", 'buyout' => 15000 }, 
  72235 => { 'name' => "Silkweed", 'buyout' => 15000 }, 
  89639 => { 'name' => "Desecrated Herb", 'buyout' => 15000 }, 
  79011 => { 'name' => "Fool's Cap", 'buyout' => 15000 }, 
  79010 => { 'name' => "Snow Lily", 'buyout' => 15000 }, 
}
# Create regular expression here to be used for filtering later
$item_regex = Regexp.new("(#{$item_filters.keys.join('|')})")
$bn_host = 'us.battle.net'
$bnah_uri = '/api/wow/auction/data'
$ah_faction = 'alliance'
$realms = [ "Aerie-Peak" ]

# Wrap up on retrieval logic so I can catch exceptions appropriately
def exception_get(http, path)
  begin
    res = http.request(Net::HTTP::Get.new(path))
    raise "Got non-200 response code (#{res.code})" if res.code.to_i != 200
  rescue => e
    puts "Error retrieving #{path}: #{e}"
  end
  return res
end

# Conversion from a number representing total amount of copper to a string showing gold, silver 
# and copper
def copper_to_gold(price)
  c = price % 100
  price = (price - c) / 100
  s = price % 100
  price = (price - s) / 100
  g = price
  return "#{g}g #{s}s #{c}c"
end

# Filter out auction data based on the filter hash provided
def filter_auctions(auction_ary, filter_hash)
  ret_ary = Array.new
  auction_ary.each do |item|
    # Skip if it's not one of our items
    next unless item['item'].to_s.match($item_regex)
    # Capture which of our match terms actually matched
    matched_item = filter_hash[$1.to_i]
    # Now that we've found a candidate item, we'll make sure the price per item is at or below
    # our threshold for that item
    ppi = item['buyout'] / item['quantity']
    next unless ppi <= matched_item['buyout']
    ret_ary << item
  end
  return ret_ary
end

# Print out a list of auctions for a realm and faction
def print_auction_list(realm, faction, lastmod, auctions)
  puts "<h1>Auctions for #{realm}-#{faction}</h1>"
  # Get the time and adjust to ET (since that's what I grok)
  t = Time.at((lastmod / 1000) + 7200)
  lastmod_s = t.to_s
  lastmod_s.gsub!('-0700', 'ET')
  puts "Data last modified on #{lastmod_s}\n<ul>"
  # If we don't have any auctions, tell them so
  if auctions.count < 1 then
    puts "<li>No auctions met specified filter criteria"
  else
    # Sort the auctions, then iterate through them printing out details
    auctions.sort! { |a, b| a['buyout'] / a['quantity'] <=> b['buyout'] / b['quantity'] }
    auctions.each do |a|
      ppi = a['buyout'] / a['quantity']
      puts "<li>Auction #{a['auc']} for #{$item_filters[a['item']]['name']} at price per item of #{copper_to_gold(ppi)} for a stack of #{a['quantity']} (#{copper_to_gold(a['buyout'])} total) by #{a['owner']}"
    end
  end
  # Close up the UL
  puts "</ul><p><hr><p>"
end

#### Start really doing stuff

print "Content-type: text/html\n\n"
puts "<html>"
puts "<body>"

$realms.each do |r|
  http = Net::HTTP.new($bn_host)
  realm_uri = URI.parse("#{$bnah_uri}/#{r}")
  puts "Retrieving data from #{realm_uri} at #{$bn_host}<p>"
  # Get the current AH data file
  @res = exception_get(http, realm_uri.path)
  location_data = JSON.parse(@res.body)

  # Now we have the json of where the data is, let's go grab it
  json_url = location_data['files'][0]['url']
  lastmod = location_data['files'][0]['lastModified']
  json_host = URI(json_url).host
  json_path = URI(json_url).path
  json_http = Net::HTTP.new(json_host)
  @res = exception_get(json_http, json_path)
  ah_data = JSON.parse(@res.body)
  auctions = ah_data[$ah_faction]['auctions']
  filtered_auctions = filter_auctions(auctions, $item_filters)
  print_auction_list(r, $ah_faction, lastmod, filtered_auctions)
end

puts "<i>Data dynamically generated just for you!</i>"
puts "</body>"
puts "</html>"
