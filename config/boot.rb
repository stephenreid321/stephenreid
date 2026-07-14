# Defines our constants
RACK_ENV = ENV['RACK_ENV'] ||= 'development' unless defined?(RACK_ENV)
PADRINO_ROOT = File.expand_path('..', __dir__) unless defined?(PADRINO_ROOT)

# Load our dependencies
require 'rubygems' unless defined?(Gem)
require 'bundler/setup'
require 'open-uri'
require 'active_support/all'
require 'shellwords'
Bundler.require(:default, RACK_ENV)

String.send(:define_method, :html_safe?) { true }

Mongoid.load!("#{PADRINO_ROOT}/config/mongoid.yml")
Mongoid.raise_not_found_error = false

require 'csv'
%w[affiliations papers softwares speaking_engagements courses books films].each do |name|
  path = "#{PADRINO_ROOT}/data/#{name}.csv"
  Object.const_set(
    name.upcase,
    CSV.read(path, headers: true).map do |row|
      row.to_h.transform_keys(&:to_sym).transform_values { |v| v.nil? || v.empty? ? nil : v }
    end.freeze
  )
end

Padrino.load!

Delayed::Worker.max_attempts = 1
