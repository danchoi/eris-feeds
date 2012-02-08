# fetches and processes feeds

require 'nokogiri'
require 'feed_yamlizer'
require 'db'

class Crawl
  def initialize(app_id)
    @app_id = app_id
  end

  def feeds
    DB["select feeds.* from feeds inner join subscriptions using (feed_id) where subscriptions.app_id = ?", @app_id].to_a
  end

  def crawl
    # TODO concurrent
    feeds.each {|feed|
      xml_url = feed[:xml_url]
      cmd = "curl -Ls '#{xml_url}' | feed2yaml"
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
          puts "Inserting item => #{item_params[:title]} (feed #{feed_id}"
          item_id = DB[:items].insert item_params
          create_summary_and_images item_id
        end
      }    
    }
  end

  def create_summary_and_images(item_id)
    html = DB[:items].first(item_id:item_id)[:original_content]
    n = nil 
    summary = if html 
      html = html.force_encoding("UTF-8")
      n = Nokogiri::HTML(html).xpath('/')
      if n
        # TODO fix this so words are not mashed together
        words = n.inner_text[0,355].split(/\s/)
        words[0..-2].join(' ') + '...' 
      end
    end
    if summary
      DB[:items].filter(item_id:item_id).update(summary:summary)
    end
    insert_images item_id, n
  end

  def insert_images item_id, n   # n is a Nokogiri node
    if n
      n.search("img").select {|img| 
        img[:height] != '1' &&
        img[:width] != '1' &&
        img[:alt] !~ /^Add to/ && 
        !DB[:images].first(src:img[:src]) 
      }.each {|img|
        filename = img[:src][/[^\/?#]+.(jpg|jpeg|git|png)/i,0]
        next unless filename
        params = {
          item_id:item_id,
          src:img[:src],
          filename:filename
        }
        DB[:images].insert params
      }
    end
  end
end

if __FILE__ == $0
  puts Crawl.new(1).crawl
end
