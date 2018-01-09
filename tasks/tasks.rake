
namespace :holdings do
  task :create_snapshots => :environment do
    Holding.create_snapshots
  end  
end
  