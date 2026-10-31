require 'bundler/setup'

task :environment do
  require_relative 'config/boot'
end

Dir[File.join(__dir__, 'tasks', '*.rake')].each { |f| load f }
