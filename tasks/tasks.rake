namespace :data do
  desc 'Fetch everything the site shows from other sites into data/fetched'
  task fetch: %i[substack iconomi public]

  desc "Fetch what needs no keys into data/fetched: the places and the courses' notes"
  task public: %i[places courses]

  desc 'Fetch the Substack notes and posts into data/fetched (needs SUBSTACK_TOKEN and SUBSTACK_PUBLICATION_URL)'
  task substack: :environment do
    SubstackNote.import
    SubstackPost.import
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

  desc "Summarise Metastrategy's proposals and what's unverified, into GitHub Actions' job summary if there is one"
  task summary: :environment do
    summary = IconomiPages.summary
    ENV['GITHUB_STEP_SUMMARY'] ? File.write(ENV['GITHUB_STEP_SUMMARY'], summary, mode: 'a') : puts(summary)
  end

  desc 'Print the strategies and assets with no status yet, for the GitHub issue the Site workflow keeps (blank if none)'
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

namespace :posts do
  desc "Post to Bluesky the links archived in Readwise in the last week that aren't on Bluesky yet"
  task sync: :environment do
    response = Faraday.get('https://readwise.io/api/v3/list', { location: 'archive', updatedAfter: 7.days.ago.iso8601 },
                           { 'Authorization' => "Token #{ENV['READWISE_ACCESS_TOKEN']}" })
    bluesky = Bluesky.new
    posted_urls = bluesky.recent_link_urls

    # Post oldest first so the newest archive item is last and sits on top of Bluesky
    JSON.parse(response.body)['results'].sort_by { |r| Time.parse(r['last_moved_at']) }.last(50).each do |r|
      url = r['source_url'].gsub('youtu.be/', 'youtube.com/watch?v=')
      next if Time.parse(r['last_moved_at']) < 7.days.ago
      next if posted_urls.include?(url)

      puts url
      title = r['title'].to_s
      bluesky.post_link(text: title, url: url, title: title, description: r['summary'].to_s.truncate(150), image_url: r['image_url'].presence)
      posted_urls << url
    end
  end
end
