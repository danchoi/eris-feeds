require 'nokogiri'
require 'feed_item'
require 'nokogiri'

class FeedCrawler
  attr_accessor :feed

  def initialize(feed)
    @feed = feed # a hash from Sequel
  end

  def update
    puts "Updating feed: #{feed[:feed_id]} #{feed[:xml_url]}"
    DB[:feeds].filter(feed_id:feed[:feed_id]).update(updated:Time.now)
    xml_url = feed[:xml_url]
    cmd = "curl -Ls -A 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.3) Gecko/2008092416 Firefox/3.0.3'  '#{xml_url}' "
    cmd += " | feed2yaml "
    puts cmd

    feedyml = `#{cmd}`
    feed_yml = YAML::load feedyml
    feed_info = feed_yml[:meta]
    items = feed_yml[:items]
    feed_params = { html_url:feed_info[:link], title:feed_info[:title].strip, xml_url:xml_url }
    if (feed = DB[:feeds].first(xml_url:feed_params[:xml_url]))
      DB[:feeds].filter(xml_url:feed_params[:xml_url]).update(feed_params)
      feed_id = feed[:feed_id]
      print '.'
    else
      puts "Adding feed #{feed_info.inspect}"
      feed_id = DB[:feeds].insert feed_params
    end
    items.each {|i| 
      unless i[:pub_date]
        puts "No pub date! Rejecting"
        next
      end
      summary = i[:content][:text]
      words = summary[0,355].split(/\s/)
      summary = words[0..-2].join(' ') + '...' 
      item_params = { 
        feed_id: feed_id,
        item_href: i[:link],
        title: i[:title],
        author: i[:author],
        date: i[:pub_date],
        original_content: i[:content][:html],
        summary: summary,
        enclosure: i[:enclosure],
        podcast_image: i[:podcast_image]
      }
      if DB[:items].first item_href: item_params[:item_href]
        $stderr.print '.'
      else
        puts "Inserting item => #{item_params[:title]} (feed #{feed_id})"
        item = FeedItem.new(DB[:items].insert(item_params))
        item.create_images 
      end
    }
  end
end

if __FILE__ == $0
  puts "Crawling feed #{ARGV.first}"
  require 'db'
  feed = DB[:feeds].first feed_id:ARGV.first
  FeedCrawler.new(feed).update
end


