namespace :artizen do
  desc 'Rebuild Artizen leaderboard caches'
  task cache: :environment do
    Artizen.refresh_cache
  end
end
