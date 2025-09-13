require_relative 'mongo_store'

# Use Mongo-backed cache for Rack::Attack throttling counters
Rack::Attack.cache.store = ActiveSupport::Cache::MongoStore.new(nil, collection: 'rack_attack_cache')

# General rate limiting - allow reasonable browsing but prevent abuse
Rack::Attack.throttle('requests by ip', limit: 300, period: 5.minutes) do |request|
  request.ip unless %w[/fonts/ /images/ /javascripts/ /stylesheets/].any? { |path| request.path.starts_with?(path) }
end

# Define throttled paths with their limits and periods
THROTTLED_PATHS = {
  '/posts/' => { limit: 5, period: 10.seconds },
  '/tao-te-ching/' => { limit: 5, period: 10.seconds },
  '/books/' => { limit: 5, period: 10.seconds }
}.freeze

# Apply throttling rules for each path
THROTTLED_PATHS.each do |path, config|
  Rack::Attack.throttle(path, limit: config[:limit], period: config[:period]) do |request|
    request.ip if request.path.starts_with?(path)
  end
end
