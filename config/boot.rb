# Loads the gems and lib/, for the rake tasks and the Jekyll site's plugin (site/_plugins/site.rb)
ROOT = File.expand_path('..', __dir__) unless defined?(ROOT)

require 'bundler/setup'
require 'active_support/all'
require 'csv'
require 'json'
require 'fileutils'
require 'open-uri'
require 'faraday'
require 'nokogiri'
require 'reverse_markdown'
require 'chroma'
require 'websocket-client-simple'

require_relative 'frontend_dependencies'
Dir[File.join(ROOT, 'lib', '*.rb')].each { |f| require f }

# The default for every thread, not just this one: Jekyll rebuilds on its file watcher's thread
Time.zone_default = Time.find_zone!('London')
