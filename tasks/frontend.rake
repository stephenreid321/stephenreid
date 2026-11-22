namespace :frontend do
  desc 'Hash each CDN file that has no hash yet into config/frontend_integrity.json, for the integrity attributes cdn_tag writes, and drop those nothing loads'
  task integrity: :environment do
    FrontendIntegrity.update
  end
end
