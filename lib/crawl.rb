# fetches and processes feeds
require 'nokogiri'
require 'feed_yamlizer'
require 'db'
require 'feed_item'

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
        item_params = { 
          feed_id: feed_id,
          item_href: i[:link],
          title: i[:title],
          author: i[:author],
          date: i[:pub_date],
          original_content: i[:content][:html]
        }
        if DB[:items].first item_href: item_params[:item_href]
          $stderr.print '.'
        else
          puts "Inserting item => #{item_params[:title]} (feed #{feed_id})"
          item = FeedItem.new(DB[:items].insert(item_params))
          item.create_summary_and_images 
        end
      }
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
