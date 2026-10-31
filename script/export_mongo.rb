#!/usr/bin/env ruby
# Once, before Mongo goes: copies what was set by hand on the old site's admin pages into data/, where it lives now.
# Writes the assets' statuses, multipliers and colours to data/iconomi_assets.csv and the strategies' statuses to
# data/iconomi_strategies.csv, and prints Metastrategy's number of assets, for the NUMBER_OF_ASSETS variable:
#
#   MONGODB_URI=$(heroku config:get MONGODB_URI -a <app>) script/export_mongo.rb
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org', cooldown: 7
  gem 'bigdecimal'
  gem 'csv'
  gem 'logger'
  gem 'mongo'
end

Mongo::Logger.logger.level = Logger::WARN
db = Mongo::Client.new(ENV.fetch('MONGODB_URI'))
data = File.expand_path('../data', __dir__)
# Blank strings as nil, as the old site treated them
blank_to_nil = ->(value) { value.respond_to?(:empty?) && value.empty? ? nil : value }

{
  'iconomi_assets' => %w[ticker name status multiplier color],
  'iconomi_strategies' => %w[ticker name status]
}.each do |name, columns|
  collection = name.delete_prefix('iconomi_')
  rows = db[collection].find.map { |doc| columns.map { |c| blank_to_nil.call(doc[c]) } }.reject { |row| row[0].nil? }.sort_by(&:first)
  CSV.open(File.join(data, "#{name}.csv"), 'w', encoding: 'UTF-8') do |csv|
    csv << columns
    rows.each { |row| csv << row }
  end
  puts "data/#{name}.csv: #{rows.size} rows"
end

puts "NUMBER_OF_ASSETS: #{db[:stashes].find(key: 'number_of_assets').first&.fetch('value')}"
