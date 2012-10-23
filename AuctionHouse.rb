#!/usr/bin/env ruby
#
# Grab data from WoW's RESTful API for the Auction House

#require 'rubygems'
require 'json'
require 'net/http'
require 'pp'

class AuctionHouse

  attr_accessor :neutral, :horde, :alliance, :realm_url, :ah_url, :ah_data

  def initialize(realm)
    @realm_url = 'http://us.battle.net/api/wow/auction/data/' + realm.downcase
  end

  def get_json_contents(url)
    resp = Net::HTTP.get_response(URI.parse(url))
    data = resp.body
    contents = JSON.parse(data)
    return contents
  end

  def grab_data
    breadcrumb = get_json_contents(@realm_url)
    puts "Got breadcrumb"
#    pp breadcrumb
    @ah_url = breadcrumb['files'][0]['url']
    puts "Got ah_url: #{@ah_url}"
#    pp @ah_url
    @ah_data = get_json_contents(@ah_url)
    puts "Got ah_data"
    pp @ah_data
  end

  def cache_data(fname)
    puts "Opening #{fname} for caching"
    fh = File.open(fname, 'w')
    puts "Writing data to file"
    fh.puts(@ah_data)
    puts "Closing file"
    fh.close
    puts "Returning"
  end

end

if $0 == __FILE__ then
  realm = 'Icecrown'
  ah = AuctionHouse.new(realm)
  ah.grab_data
  fn = 'ah.data-' + realm
  ah.cache_data(fn)
end
