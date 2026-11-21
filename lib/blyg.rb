# Stephen's blyg (https://blyg.stephenreid.net, cloudflare/blyg): Blygger Studio's owner API, with the token in
# BLYG_ACCESS_TOKEN, made in its Studio under More → Client access (REST API, with owner:draft and owner:publish). It
# expires after 30 days
class Blyg
  URL = 'https://blyg.stephenreid.net/'.freeze

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
