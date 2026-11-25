# Semble (https://semble.so), the AT Protocol app for collecting links. It has no API to write to: it reads the cards
# in each account's repo from the firehose, so a card is a network.cosmik.card record (its lexicon is in
# cosmik-network/semble), written to the Bluesky account in BLUESKY_EMAIL and BLUESKY_PASSWORD
class Semble
  CARD = 'network.cosmik.card'.freeze

  # Adds to Semble the links archived in Readwise in the last week that aren't among its cards yet, oldest first, each as
  # a URL card with what Readwise knows of it, and prints each as it's added. For rake semble:post
  def self.post_from_readwise(semble = new)
    Readwise.to_post(semble.recent_card_urls).each do |r|
      puts r['source_url']
      semble.add_url(url: r['source_url'], title: r['title'], description: r['summary'], author: r['author'], image_url: r['image_url'])
    end
  end

  def initialize(bluesky = Bluesky.new)
    @bluesky = bluesky
  end

  # The URLs of the account's last 100 URL cards
  def recent_card_urls
    @bluesky.records(CARD).filter_map { |r| r.dig('value', 'content', 'url') if r.dig('value', 'type') == 'URL' }
  end

  # Writes a URL card. Semble fetches the page's metadata itself; this is what it shows until then, and only what's known,
  # as the lexicon takes no nulls
  def add_url(url:, title: nil, description: nil, author: nil, image_url: nil)
    metadata = { title: title.to_s.squish, description: description.to_s.squish, author: author.to_s.squish, imageUrl: image_url }.compact_blank
    content = { '$type' => "#{CARD}#urlContent", url: url }
    content[:metadata] = metadata.merge('$type' => "#{CARD}#urlMetadata") if metadata.any?
    @bluesky.create_record(CARD, type: 'URL', content: content, createdAt: Time.now.utc.iso8601(3))
  end
end
