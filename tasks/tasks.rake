namespace :strategies do
  task update: :environment do
    Strategy.import
    Strategy.update
  end

  task rebalance: :environment do
    Strategy.rebalance if Time.now.wday == 5
  end

  task rebalance_without_update: :environment do
    Strategy.rebalance(skip_update: true) if Time.now.wday == 5
  end

  task propose: :environment do
    Strategy.propose_and_stash
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

namespace :substack do
  task import: :environment do
    SubstackNote.import
    SubstackPost.import
  end
end
