require 'db'
require 'yaml'
seeds = YAML::load_file File.join(File.dirname(__FILE__), 'seeds.yml')

seeds['applications'].each {|app|
  app_id = DB[:applications].insert app['config']
  app['feeds'].each {|feed_url|
    feed_id = DB[:feeds].insert xml_url:feed_url
    DB[:subscriptions].insert app_id:app_id, feed_id:feed_id
  }
}

