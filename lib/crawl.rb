# fetches and processes feeds
require 'nokogiri'
require 'feed_yamlizer'
require 'db'
require 'feed_crawler'

class Crawl
  def initialize(crawl_id)
    @crawl_id = crawl_id
    @crawl = DB[:crawls].first(crawl_id:crawl_id)
    @app_id = @crawl[:app_id]
  end

  def feeds
    DB["select feeds.* from feeds inner join subscriptions using (feed_id) where subscriptions.app_id = ?", @app_id].to_a
  end

  def crawl
    # TODO concurrent
    DB[:crawls].filter(crawl_id:@crawl_id).update(started:Time.now)
    feeds.each {|feed|
      FeedCrawler.new(feed).update
    }
    DB[:crawls].filter(crawl_id:@crawl_id).update(completed:Time.now)
  end
end

if __FILE__ == $0
  DB[:crawls].filter(started:nil).order(:created.asc).each {|r|
    crawl_id = r[:crawl_id]
    puts "Starting crawl: #{crawl_id}"
    Crawl.new(crawl_id).crawl
  }
end
