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
  }

  get('/applications') {
    DB[:applications].all.to_a.to_json
  }

  post('/applications') {
    payload = JSON.parse request.body.read
    ds = DB[:applications]
    if ds.first(app_name: payload['app_name'])
      halt 403, "App name already taken"
    else
      app_id = ds.insert payload
      ds.first(app_id:app_id).to_hash.to_json
    end
  }
  
  put('/application/:id') {|app_id|   
    payload = JSON.parse request.body.read
    DB[:applications].filter(app_id:app_id).update(payload)
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

  post('/application/:app_id/crawls') {|app_id|
    crawl_id = DB[:crawls].insert(app_id:app_id) 
    status 201
    resource = DB[:crawls].first(crawl_id:crawl_id).to_hash
    resource.
      merge({link: {rel: 'self', href: url_for("/crawl/#{crawl_id}")}}).  # hypermedia
      to_json
  }

  get('/crawls/:id') {|crawl_id|
    DB[:crawls].first(crawl_id:crawl_id).to_hash.to_json
  }

  run! if app_file == $0
end
