namespace :data do
  desc 'Fetch everything the site shows from other sites into data/fetched'
  task fetch: %i[substack iconomi public]

  desc "Fetch what needs no keys into data/fetched: the places and the courses' notes"
  task public: %i[places courses]

  desc 'Fetch the Substack notes and posts into data/fetched (needs SUBSTACK_TOKEN and SUBSTACK_PUBLICATION_URL)'
  task substack: :environment do
    # At once, as each pages through Substack's API a page at a time, and they share nothing but the token
    [Thread.new { SubstackNote.import }, Thread.new { SubstackPost.import }].each(&:join)
  end

  desc "Fetch the last 90 days' posts of the newsletters Stephen subscribes to on Substack into data/fetched, for /substack"
  task substack_surfacer: :environment do
    SubstackSurfacer.fetch
  end

  desc 'Export the library from Goodreads into data/goodreads_library_export.csv (needs GOODREADS_COOKIE)'
  task goodreads: :environment do
    Goodreads.fetch
  end

  desc 'Fetch the ICONOMI strategies and Metastrategy into data/fetched (needs ICN_API_KEY and ICN_SECRET)'
  task iconomi: :environment do
    next puts 'ℹ️  ICONOMI fetch skipped: set ICN_API_KEY and ICN_SECRET.' if ENV['ICN_API_KEY'].blank?

    Strategy.fetch
  end

  desc 'Fetch the places on the treasure map into data/fetched'
  task places: :environment do
    Places.fetch
  end

  desc "Fetch the courses' notes into data/fetched"
  task courses: :environment do
    Course.fetch
  end
end

namespace :iconomi do
  desc 'Mark the strategies and assets with no status as verified, in data/iconomi/strategies.csv and data/iconomi/assets.csv'
  task verify: :environment do
    puts "Verified: #{Strategy.verify.join(', ').presence || 'nothing new'}"
  end

  desc 'Rebalance Metastrategy on ICONOMI, after fetching the strategies afresh (needs NUMBER_OF_ASSETS)'
  task rebalance: :environment do
    Strategy.rebalance
  end

  desc 'Print the strategies and assets with no status yet, for the GitHub issue iconomi-fetch.yml keeps (blank if none)'
  task unreviewed: :environment do
    print IconomiPages.unreviewed
  end
end

namespace :site do
  desc 'Build the site into _site, from what data/fetched holds'
  task :build do
    sh 'bundle exec jekyll build'
  end

  desc 'Serve the site at http://localhost:4000, rebuilding it as files change'
  task :serve do
    sh 'bundle exec jekyll serve --livereload'
  end
end

namespace :bluesky do
  desc "Post to Bluesky the links archived in Readwise in the last week that aren't on Bluesky yet"
  task post: :environment do
    bluesky = Bluesky.new
    posted_urls = bluesky.recent_link_urls

    # Post oldest first so the newest archive item is last and sits on top of Bluesky
    Readwise.archived_since(7.days.ago).last(50).each do |r|
      url = r['source_url']
      next if posted_urls.include?(url)

      puts url
      title = r['title'].to_s
      bluesky.post_link(text: title, url: url, title: title, description: r['summary'].to_s.truncate(150), image_url: r['image_url'].presence)
      posted_urls << url
    end
  end
end
