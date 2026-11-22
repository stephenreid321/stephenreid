# Stephen's blyg (https://blyg.stephenreid.net, cloudflare/blyg): Blygger Studio's owner API, with the token in
# BLYG_ACCESS_TOKEN, made in its Studio under More → Client access (REST API, with owner:draft and owner:publish). It
# expires after 30 days
class Blyg
  URL = 'https://blyg.stephenreid.net/'.freeze

  # Publishes the links archived in Readwise in the last week since the newest one on the blyg, oldest first, and prints
  # each as it's published. Only those archived after the newest on it already, so a link never lands above one archived
  # after it: one missed is left out rather than posted out of order. For rake blyg:post
  def self.post_from_readwise(blyg = new)
    Readwise.to_post(recent_link_urls, after_newest: true).each do |r|
      puts r['source_url']
      blyg.post_link(url: r['source_url'], title: r['title'].presence || r['source_url'], author: r['author'])
    end
  end

  def initialize(token: ENV.fetch('BLYG_ACCESS_TOKEN'))
    @http = Faraday.new(url: "#{URL}api/") do |f|
      f.request :json
      f.response :json
      f.response :raise_error
      f.headers['Authorization'] = "Bearer #{token}"
    end
  end

  # The URLs linked from the posts in the blyg's public feed. It isn't the API's, which would need owner:read too, and
  # it's cached for up to a minute: fine for links archived over a week
  def self.recent_link_urls
    response = Faraday.get("#{URL}feed.xml")
    raise "#{URL}feed.xml: #{response.status}" unless response.success?

    Nokogiri::XML(response.body).xpath('//item/description').flat_map do |description|
      Nokogiri::HTML.fragment(description.text).css('a[href]').map { |a| a['href'] }
    end
  end

  # Publishes a fragment linking to url: its title, linked, then who wrote it, as a Markdown link and an em dash
  def post_link(url:, title:, author: nil)
    text = "[#{title.to_s.squish.gsub(/([\[\]\\])/, '\\\\\1')}](#{url.gsub(')', '%29')})"
    # Not when Readwise doesn't know who, and names the site instead: Substack, or a domain
    text += " — #{author.squish}" if author.present? && author != 'Substack' && !author.match?(/\A[\w-]+(\.[\w-]+)+\z/)
    item = @http.post('items', mode: 'blank', kind: 'fragment', contentMd: text).body
    item = item['item'] || item
    @http.post("items/#{item['id']}/publish", expectedRevision: item['revision'])
  end
end
