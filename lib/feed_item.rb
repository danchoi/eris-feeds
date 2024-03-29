class FeedItem
  attr_reader :item_id

  def initialize(item_id)
    @item_id = item_id
    @item = DB[:items].first(item_id:@item_id)
    @feed = DB[:feeds].first(feed_id:@item[:feed_id])
  end

  def create_summary_and_images
    html = DB[:items].first(item_id:@item_id)[:original_content]
    n, word_count = nil, nil
    summary = if html 
      html = html.force_encoding("UTF-8")
      n = Nokogiri::HTML(html).xpath('/')
      if n
        # fix this so words are not mashed together
        n.xpath("//text()").each {|s|
          s.content = " #{s.content} "
        }
        # store word count
        word_count = n.inner_text.split(/\s+/).size
        words = n.inner_text.strip[0,355].split(/\s+/)
        words[0..-2].join(' ') + '...' 
      end
    end
    if summary
      DB[:items].filter(item_id:@item_id).update(summary:summary, word_count:word_count)
    end
    insert_images n
    process_images
  end

  def insert_images n   # n is a Nokogiri node
    if n
      n.search("img").each_with_index {|img, idx|
        if img[:height] != '1' &&
          img[:width] != '1' && img[:alt] !~ /^Add to/ && 
          !DB[:images].first(src:img[:src]) && img[:src] !~ /placeholder/

          ext = img[:src][/[^\/?#]+.(jpg|jpeg|gif|png)/i,1]
          src = img[:src] 
          if src =~ /^\//
            base_url = @feed[:html_url][/^https?:\/\/[^\/]+/,0]
            src = "#{base_url}#{img[:src]}"
            puts "Setting img[:src] to #{src}"
          end
          next unless (ext  && src =~ /^http/)
          filename = "#{idx}.#{ext}"
          params = {
            item_id:@item_id,
            src:src,
            filename:filename
          }
          DB[:images].insert params
        else
          img.remove
        end
      }
    end
  end

  def process_images
    puts "Processing images for item #{@item_id}"
    DB[:images].filter(item_id:@item_id).order(:inserted_at.asc).map.with_index {|image, idx|
      dir = "img/#{@item_id}"
      path = "#{dir}/#{image[:filename]}"
      unless File.size?(path)
        run "mkdir -p #{dir}"
        run "wget -O #{path} '#{image[:src]}'"
        run "convert #{path} -resize '200x150>' #{path}.tmp"
        run "mv #{path}.tmp #{path}"
        /(?<width>\d+)x(?<height>\d+) / =~ run("identify #{path}")
        puts "Image dimensions: #{width}image#{height}"
        DB[:images].filter(image_id:image[:image_id]).update(width:width, height:height)
      end
      if idx == 0 && File.size?(path)
        DB[:items].filter(item_id:image[:item_id]).update(featured_image_id:image[:image_id])
      end
    }
  end


  def run(command)
    puts command
    `#{command}`
  end



end
