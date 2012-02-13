require 'db'
require 'nokogiri'
DB[:items].each do |item|
  d = Nokogiri::HTML(item[:original_content])
  d.xpath("//text()").each {|n| n.content = "#{n.content} "}
  wc = d.inner_text.split(/\s+/).size
  item[:word_count] = wc
  puts "%s => %d" % [item[:title], wc]
  DB[:items].filter(item_id:item[:item_id]).update(word_count:wc)
end
