# Bluesky's HTTP API (AT Protocol), as the account in BLUESKY_EMAIL and BLUESKY_PASSWORD
class Bluesky
  API = 'https://bsky.social/xrpc/'.freeze
  MAX_IMAGE_BYTES = 1_000_000 # Bluesky's limit for an image
  MAX_TEXT_LENGTH = 300 # Bluesky's limit for a post, in characters

  def initialize(identifier: ENV['BLUESKY_EMAIL'], password: ENV['BLUESKY_PASSWORD'])
    @http = Faraday.new(url: API) do |f|
      f.request :json
      f.response :json
      f.response :raise_error
    end
    session = @http.post('com.atproto.server.createSession', identifier: identifier, password: password).body
    @did = session['did']
    @http.headers['Authorization'] = "Bearer #{session['accessJwt']}"
  end

  # The URLs of the links in the account's last 100 posts
  def recent_link_urls
    @http.get('app.bsky.feed.getAuthorFeed', actor: @did, limit: 100).body['feed'].filter_map do |item|
      item.dig('post', 'record', 'embed', 'external', 'uri')
    end
  end

  # Posts text with a card for a link. The card shows the image if it can be fetched and is small enough, and if posting
  # with it fails, posts without it
  def post_link(text:, url:, title:, description:, image_url: nil)
    card = { uri: url, title: title, description: description }
    thumb = upload_image(image_url) if image_url.present?
    create_post(text, thumb ? card.merge(thumb: thumb) : card)
  rescue Faraday::Error
    raise unless thumb

    create_post(text, card)
  end

  private

  # The uploaded image's blob, or nil if it can't be fetched or is too big
  def upload_image(url)
    image = Faraday.get(url) { |req| req.options.timeout = 20 }
    return unless image.success? && image.body.bytesize < MAX_IMAGE_BYTES

    @http.post('com.atproto.repo.uploadBlob', image.body, 'Content-Type' => image.headers['content-type'] || 'image/jpeg').body['blob']
  rescue Faraday::Error, URI::InvalidURIError
    nil
  end

  def create_post(text, card)
    @http.post('com.atproto.repo.createRecord', repo: @did, collection: 'app.bsky.feed.post', record: {
                 '$type' => 'app.bsky.feed.post',
                 text: text.truncate(MAX_TEXT_LENGTH),
                 createdAt: Time.now.utc.iso8601(3),
                 langs: ['en'],
                 embed: { '$type' => 'app.bsky.embed.external', external: card }
               })
  end
end
