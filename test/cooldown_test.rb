require 'test_config'

class CooldownTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 11, 22, 12)

  test 'refuses what was released less than 7 days ago, saying how long ago' do
    error = assert_raises(RuntimeError) { Cooldown.check!('pkg@1.0.0', '2026-11-20T00:00:00Z', now: NOW) }

    assert_equal 'pkg@1.0.0: released 2.5 days ago, under the 7-day cooldown', error.message
  end

  test 'allows what is 7 days old or more' do
    assert_nil Cooldown.check!('pkg@1.0.0', '2026-11-15T12:00:00Z', now: NOW)
    assert_nil Cooldown.check!('pkg@1.0.0', Time.utc(2025, 1, 1), now: NOW)
  end

  test "gives npm install's --before as the date 7 days ago" do
    assert_equal '2026-11-15', Cooldown.before(today: Date.new(2026, 11, 22))
  end

  test 'every task that installs or pins a dependency keeps to it' do
    %w[lib/frontend_integrity.rb lib/blygger_release.rb].each { |file| assert_includes File.read(File.join(ROOT, file)), 'Cooldown.check!', file }
    assert_includes File.read(File.join(ROOT, 'lib/stylesheets.rb')), "--before=\#{Cooldown.before}"
    assert_includes File.read(File.join(ROOT, 'Gemfile')), "cooldown: #{Cooldown::DAYS}"
  end
end
