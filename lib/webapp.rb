require 'sinatra'
require 'json'
require 'uri'
require 'db'

BASE_URL = "http://localhost:9393"

class FeedService < Sinatra::Base
  set :static, true
  set :root, File.dirname(__FILE__)

  helpers {
    def url_for(path)
      [BASE_URL, path].join
    end
  }

  get('/application/:app_id/items') {|app_id|
    items = DB[:app_items].filter(app_id:app_id).order(:date.desc).limit(100)
    items = items.filter("date > ?", params[:from_time]) if params[:from_time]
    items.to_a.to_json
  }

  get('/applications') {
    # TODO include hypermedia links
    apps = DB[:applications].all.to_a
    apps.map {|app|
      app.to_hash.merge({links: [
        { link: url_for("/application/#{app[:app_id]}"), rel: "self"  }
      ]})
    }.to_json
  }

  # representation includes subscription list
  # TODO hypermedia link to self, subscriptions, crawls

  get('/application/:id') {|app_id|

    subscriptions = DB["select feeds.title, feeds.xml_url, feeds.html_url, 
      feed_id, feeds.updated from subscriptions 
      inner join feeds using (feed_id) where subscriptions.app_id = ?", app_id]
    puts subscriptions.sql

    DB[:applications].first(app_id:app_id).to_hash.
      merge(subscriptions:subscriptions.to_a).
        merge(links: [
          { link:url_for("/application/#{app_id}"), rel:'self' }
        ]).
        to_json
  }

  put('/application/:id') {|app_id|   
    payload = JSON.parse request.body.read
    if DB[:applications].first(app_id:app_id)
      DB[:applications].filter(app_id:app_id).update(payload)
    else
      status 201
      DB[:applications].insert(payload)
    end
    DB[:applications].first(app_id:app_id).to_json
  }

  delete('/application/:id') {|app_id|
    ds = DB[:applications].filter(app_id:app_id)
    if ds.empty?
      halt 404
    end
    application = ds.first.to_hash
    ds.delete
    application.to_json
  }

  # payload must contain feed_xml_url 
  post('/application/:app_id/subscriptions') {|app_id|
    feed_xml_url = JSON.parse(request.body.read)['feed_xml_url']
    sub_id = if (f = DB[:feeds].first(xml_url:feed_xml_url)) && (DB[:subscriptions].first(feed_id:f[:feed_id]).nil?)
      feed_id = f[:feed_id]
      DB[:subscriptions].insert(feed_id:feed_id, app_id:app_id)
    else
      feed_id = DB[:feeds].insert(xml_url:feed_xml_url)
      DB[:subscriptions].insert(feed_id:feed_id, app_id:app_id)
    end
    status 201
    DB[:subscriptions].first(app_id:app_id, feed_id:feed_id).to_hash.to_json
  }

  get('/application/:app_id/subscriptions') {|app_id|

  }

  post('/application/:app_id/crawls') {|app_id|
    crawl_id = DB[:crawls].insert(app_id:app_id) 
    status 201
    resource = DB[:crawls].first(crawl_id:crawl_id).to_hash
    resource.
      merge({link: {rel: 'self', href: url_for("/crawl/#{crawl_id}")}}).  # hypermedia
      to_json
  }

  get('/application/:app_id/crawls') {|app_id|
    { 
      app_id: app_id,
      crawls: DB[:crawls].filter(app_id:app_id).to_a 
    }.to_json
  }

  get('/crawls/:id') {|crawl_id|
    DB[:crawls].first(crawl_id:crawl_id).to_hash.to_json
  }

  run! if app_file == $0
end
