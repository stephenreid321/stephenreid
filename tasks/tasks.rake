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

namespace :tweets do
  task import: :environment do
    Tweet.import if ENV['TWEETS_IMPORT']
  end
  task nitter: :environment do
    Tweet.nitter if ENV['TWEETS_IMPORT']
  end
end

namespace :verses do
  task update_owners: :environment do
    Verse.all.each(&:update_owner)
  end
end

namespace :terms do
  task create_edges: :environment do
    term_ids = []
    Post.all(filter: "IS_AFTER({Created at}, '#{1.day.ago.to_s(:db)}')").each do |post|
      term_ids += post['Terms'] if post['Terms']
    end
    term_ids.uniq.each do |term_id|
      term = Term.find(term_id)
      puts term['Name']
      term.create_edges
    end
  end
end

namespace :posts do
  task sync: :environment do
    # Post.sync_with_pocket
    Post.sync_with_readwise
  end

  task delete_duplicates: :environment do
    links = Post.all.map { |post| post['Link'] }
    dupes = links.select { |link| links.count(link) > 1 }
    dupes.uniq.each do |link|
      posts = Post.all(filter: "{Link} = '#{link}'", sort: { 'Created at' => 'desc' })
      posts[1..].each do |post|
        puts "destroying #{post['Link']} created #{post['Created at']}"
        post.destroy
      end
    end
  end

  task tag_new: :environment do
    term_ids = []
    agent = Mechanize.new
    Post.all(filter: "{Title} = ''").each do |post|
      result = agent.get("https://iframe.ly/api/iframely?url=#{URI.encode_www_form_component(post['Link'].split('#').first)}&api_key=#{ENV['IFRAMELY_API_KEY']}")

      post['Iframely'] = result.body.force_encoding('UTF-8')

      json = JSON.parse(post['Iframely'])

      puts(post['Title'] = json['meta']['title'])
      post['Body'] = json['meta']['description']

      post.save

      if post['Title']
        post.tagify(skip_linking: true)
        term_ids += post['Terms'] if post['Terms']
      end
    end

    puts term_ids.count
    term_ids.uniq.each do |term_id|
      term = Term.find(term_id)
      puts term['Name']
      term.create_edges
    end
  end
end

namespace :coins do
  task import: :environment do
    Coin.import
  end

  task remote_update: :environment do
    coinships = Coinship.and(:id.in => Coinship.and(starred: true).pluck(:id) + Coinship.and(:tag_id.ne => nil).pluck(:id))
    Coin.and(:id.in => coinships.pluck(:coin_id)).each do |coin|
      puts coin.slug
      coin.remote_update
    end
    coinships.each do |coinship|
      puts "#{coinship.account.name} ~ #{coinship.coin.slug}"
      coinship.remote_update(skip_coin_update: true)
    end
  end
end

namespace :tags do
  task update_holdings: :environment do
    Tag.update_holdings
  end
end
