require_relative 'mongo_store'

# Use Mongo-backed cache for Rack::Attack throttling counters
Rack::Attack.cache.store = ActiveSupport::Cache::MongoStore.new(nil, collection: 'rack_attack_cache')

# General rate limiting - allow reasonable browsing but prevent abuse
Rack::Attack.throttle('requests by ip', limit: 300, period: 5.minutes) do |request|
  request.ip unless %w[/fonts/ /images/ /javascripts/ /stylesheets/].any? { |path| request.path.starts_with?(path) }
end

Rack::Attack.throttle('/posts/', limit: 10, period: 10.seconds) do |request|
  request.ip if request.path.starts_with?('/posts/')
end

Rack::Attack.throttle('/tao-te-ching/', limit: 10, period: 10.seconds) do |request|
  request.ip if request.path.starts_with?('/tao-te-ching/')
end
