require 'date'
require 'time'

# AGENTS.md's cooldown: never a version of a dependency released less than DAYS days ago, which guards against
# supply-chain attacks on freshly published versions. Loaded on its own by the rake tasks that don't boot the app
module Cooldown
  DAYS = 7

  # Raises unless what was released at this time is at least DAYS days old
  def self.check!(name, released_at, now: Time.now)
    age = now - Time.parse(released_at.to_s)
    raise "#{name}: released #{format('%.1f', age / 86_400)} days ago, under the #{DAYS}-day cooldown" if age < DAYS * 86_400
  end

  # The date DAYS days ago, for npm install --before
  def self.before(today: Date.today)
    (today - DAYS).iso8601
  end
end
