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
  task sync: :environment do
    conn = Faraday.new(url: 'https://readwise.io/api/v3') do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get('list', {
                          location: 'archive',
                          updatedAfter: 7.days.ago.iso8601
                        }) do |req|
      req.headers['Authorization'] = "Token #{ENV['READWISE_ACCESS_TOKEN']}"
      req.headers['Content-Type'] = 'application/json'
    end

    posted_urls = `python #{Shellwords.escape(Padrino.root.to_s)}/scripts/bluesky.py --recent-urls`
                  .lines.map(&:strip).reject(&:empty?)

    data = JSON.parse(response.body)
    data['results'].first(50).sort_by { |r| -Time.parse(r['last_moved_at']).to_i }.each do |r|
      url = r['source_url'].gsub('youtu.be/', 'youtube.com/watch?v=')
      next if Time.parse(r['last_moved_at']) < 7.days.ago
      next if posted_urls.include?(url)

      puts url

      title = r['title'].to_s
      description = r['summary'].to_s.truncate(150)
      thumbnail = r['image_url'].to_s

      args = [Shellwords.escape(title), Shellwords.escape(url), Shellwords.escape(title), Shellwords.escape(description)]
      args << Shellwords.escape(thumbnail) if thumbnail.present?
      `python #{Shellwords.escape(Padrino.root.to_s)}/scripts/bluesky.py #{args.join(' ')}`
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
