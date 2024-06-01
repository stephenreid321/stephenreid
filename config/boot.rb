# Defines our constants
RACK_ENV = ENV['RACK_ENV'] ||= 'development' unless defined?(RACK_ENV)
PADRINO_ROOT = File.expand_path('..', __dir__) unless defined?(PADRINO_ROOT)

# Load our dependencies
require 'rubygems' unless defined?(Gem)
require 'bundler/setup'
require 'open-uri'
require 'active_support/all'
require 'telegram/bot'
Bundler.require(:default, RACK_ENV)

String.send(:define_method, :html_safe?) { true }

Padrino.load!

Mongoid.load!("#{PADRINO_ROOT}/config/mongoid.yml")
Mongoid.raise_not_found_error = false

Delayed::Worker.max_attempts = 1

Airrecord.api_key = ENV['AIRTABLE_API_KEY']
module Airrecord
  class Table
    def self.since(time)
      all(filter: "{Created at} >= '#{time.to_s(:db)}'")
    end
  end
end

Anthropic.configure do |config|
  config.access_token = ENV['ANTHROPIC_API_KEY']
end

if ENV['GEMINI_API_KEY']
  GEMINI_PRO = Gemini.new(
    credentials: {
      service: 'generative-language-api',
      api_key: ENV['GEMINI_API_KEY']
    },
    options: { model: 'gemini-1.5-pro', server_sent_events: true }
  )
  GEMINI_FLASH = Gemini.new(
    credentials: {
      service: 'generative-language-api',
      api_key: ENV['GEMINI_API_KEY']
    },
    options: { model: 'gemini-1.5-flash', server_sent_events: true }
  )
end
