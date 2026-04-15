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
    Post.all(filter: "{Title} = ''").each do |post|
      post['Iframely'] = Faraday.get("https://iframe.ly/api/iframely?url=#{URI.encode_www_form_component(post['Link'].split('#').first)}&api_key=#{ENV['IFRAMELY_API_KEY']}").body.force_encoding('UTF-8')

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

namespace :substack_notes do
  task import: :environment do
    SubstackNote.import
  end
end

namespace :substack_posts do
  task import: :environment do
    SubstackPost.import
  end
end

namespace :substack do
  task import: :environment do
    SubstackNote.import
    SubstackPost.import
  end
end
