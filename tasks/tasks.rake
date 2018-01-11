
namespace :holdings do
  task :create_snapshots => :environment do
    Holding.create_snapshots
  end  
end

namespace :prices do
  task :snap => :environment do
    Price.snap
  end  
end
  