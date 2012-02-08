class FeedItem
  attr_reader :item_id

  def initialize(item_id)
    @item_id = item_id
  end

  def create_summary_and_images
    html = DB[:items].first(item_id:@item_id)[:original_content]
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
      DB[:items].filter(item_id:@item_id).update(summary:summary)
    end
    insert_images n
    process_images
  end

  def insert_images n   # n is a Nokogiri node
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
          item_id:@item_id,
          src:img[:src],
          filename:filename
        }
        DB[:images].insert params
      }
    end
  end

  def process_images
    puts "Processing images for item #{@item_id}"
    DB[:images].filter(item_id:@item_id).order(:inserted_at.asc).map.with_index {|image, idx|
      if idx == 0
        DB[:items].filter(item_id:image[:item_id]).update(featured_image_id:image[:image_id])
      end
      dir = "img/#{@item_id}"
      path = "#{dir}/#{image[:filename]}"
      unless File.exist?(path)
        run "mkdir -p #{dir}"
        run "wget -O #{path} '#{image[:src]}'"
        run "convert #{path} -resize '200x150>' #{path}.tmp"
        run "mv #{path}.tmp #{path}"
        /(?<width>\d+)x(?<height>\d+) / =~ run("identify #{path}")
        puts "Image dimensions: #{width}image#{height}"
        DB[:images].filter(image_id:image[:image_id]).update(width:width, height:height)
      end
    }
  end


  def run(command)
    puts command
    `#{command}`
  end



end
