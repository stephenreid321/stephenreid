namespace :stylesheets do
  desc 'Compile site/stylesheets/dark.scss and light.scss, with Bootstrap at the version in config/frontend_package.json (needs Node)'
  task build: :environment do
    Stylesheets.build
  end
end
