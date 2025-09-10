require_relative 'mongo_store'

# Use Mongo-backed cache for Rack::Attack throttling counters
Rack::Attack.cache.store = ActiveSupport::Cache::MongoStore.new(nil, collection: 'rack_attack_cache')

# General rate limiting - allow reasonable browsing but prevent abuse
Rack::Attack.throttle('requests by ip', limit: 300, period: 5.minutes) do |request|
  request.ip
end
