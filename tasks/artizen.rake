namespace :artizen do
  desc 'Rebuild Artizen leaderboard, project, and fund caches'
  task cache: :environment do
    Artizen.refresh_cache
  end
end
