require 'test_config'
require 'helpers/readwise_helpers'

# Bluesky.post_from_readwise and Blyg.post_from_readwise, which readwise.yml runs (rake bluesky:post, blyg:post)
class ReadwisePostingTest < ActiveSupport::TestCase
  include ReadwiseHelpers

  BSKY = 'https://bsky.social/xrpc/'.freeze
  BLYG = 'https://blyg.stephenreid.net/'.freeze

  def blyg_feed(*urls)
    items = urls.map { |url| "<item><description>#{CGI.escapeHTML(%(<p><a href="#{url}">a link</a></p>))}</description></item>" }
    [200, { 'Content-Type' => 'application/rss+xml' }, "<rss><channel>#{items.join}</channel></rss>"]
  end

  def with_tokens(&)
    with_env('READWISE_ACCESS_TOKEN' => 'r', 'BLUESKY_EMAIL' => 'e', 'BLUESKY_PASSWORD' => 'p', 'BLYG_ACCESS_TOKEN' => 'b', &)
  end

  test 'posts to Bluesky, oldest first, what is not on Bluesky yet, as a card for each link' do
    records = []
    stub_readwise(%w[https://a.com/1 https://a.com/2 https://a.com/3]) do |stub|
      stub.post("#{BSKY}com.atproto.server.createSession") { json('did' => 'did:me', 'accessJwt' => 'jwt') }
      stub.get("#{BSKY}app.bsky.feed.getAuthorFeed") do
        json('feed' => [{ 'post' => { 'record' => { 'embed' => { 'external' => { 'uri' => 'https://a.com/2?utm_source=x' } } } } }])
      end
      stub.post("#{BSKY}com.atproto.repo.createRecord") do |env|
        records << [env.request_headers['Authorization'], JSON.parse(env.request_body)]
        json({})
      end
    end

    out = with_tokens { capture_io { Bluesky.post_from_readwise }.first }

    assert_equal "https://a.com/1\nhttps://a.com/3\n", out
    assert_equal ['Bearer jwt'], records.map(&:first).uniq
    record = records.first.last

    assert_equal 'did:me', record['repo']
    assert_equal 'Title of https://a.com/1', record.dig('record', 'text')
    assert_equal({ 'uri' => 'https://a.com/1', 'title' => 'Title of https://a.com/1', 'description' => '' }, record.dig('record', 'embed', 'external'))
  end

  test "a link card's image that's too big, or won't post, is left off the post rather than holding it up" do
    records = []
    stub_http do |stub|
      stub.post("#{BSKY}com.atproto.server.createSession") { json('did' => 'did:me', 'accessJwt' => 'jwt') }
      stub.get('https://a.com/big.jpg') { [200, { 'Content-Type' => 'image/jpeg' }, 'x' * Bluesky::MAX_IMAGE_BYTES] }
      stub.get('https://a.com/small.jpg') { [200, { 'Content-Type' => 'image/jpeg' }, 'jpeg'] }
      stub.post("#{BSKY}com.atproto.repo.uploadBlob") { json('blob' => { 'ref' => 'blob' }) }
      stub.post("#{BSKY}com.atproto.repo.createRecord") do |env|
        external = JSON.parse(env.request_body).dig('record', 'embed', 'external')
        records << external
        external['thumb'] ? [400, {}, '{}'] : json({})
      end
    end
    bluesky = Bluesky.new(identifier: 'e', password: 'p')

    bluesky.post_link(text: 't', url: 'https://a.com', title: 't', description: 'd', image_url: 'https://a.com/big.jpg')
    bluesky.post_link(text: 't', url: 'https://a.com', title: 't', description: 'd', image_url: 'https://a.com/small.jpg')

    # The big one with no image; the small one with it, refused, then without
    assert_equal [nil, { 'ref' => 'blob' }, nil], records.pluck('thumb')
  end

  test "publishes to the blyg what was archived after the newest that's on it, each linked and by its author" do
    items = []
    stub_readwise(%w[https://a.com/1 https://a.com/2 https://a.com/3]) do |stub|
      stub.get("#{BLYG}feed.xml") { blyg_feed('https://a.com/2?utm_medium=email') }
      stub.post("#{BLYG}api/items") do |env|
        items << [env.request_headers['Authorization'], JSON.parse(env.request_body)]
        json('item' => { 'id' => 'i1', 'revision' => 3 })
      end
      stub.post("#{BLYG}api/items/i1/publish") { |env| json('published' => JSON.parse(env.request_body)) }
    end

    out = with_tokens { capture_io { Blyg.post_from_readwise }.first }

    # Not 1, archived before 2, which is on the blyg already
    assert_equal "https://a.com/3\n", out
    assert_equal [['Bearer b', { 'mode' => 'blank', 'kind' => 'fragment', 'contentMd' => '[Title of https://a.com/3](https://a.com/3)' }]], items
  end

  test "fails when the blyg's feed won't load, rather than posting what may be on it already" do
    stub_readwise(%w[https://a.com/1]) { |stub| stub.get("#{BLYG}feed.xml") { [503, {}, ''] } }

    error = assert_raises(RuntimeError) { with_tokens { capture_io { Blyg.post_from_readwise }.first } }

    assert_match(/feed.xml: 503/, error.message)
  end

  test "a blyg post's link escapes what Markdown would read, and names its author unless Readwise named the site" do
    texts = []
    stub_http do |stub|
      stub.post("#{BLYG}api/items") do |env|
        texts << JSON.parse(env.request_body)['contentMd']
        json('id' => 'i1', 'revision' => 1)
      end
      stub.post("#{BLYG}api/items/i1/publish") { json({}) }
    end
    blyg = Blyg.new(token: 'b')

    blyg.post_link(url: 'https://a.com/x_(y)', title: "A [bracketed]\n  title", author: '  Jane   Doe ')
    blyg.post_link(url: 'https://a.com', title: 'T', author: 'Substack')
    blyg.post_link(url: 'https://a.com', title: 'T', author: 'www.example.co.uk')

    assert_equal ['[A \\[bracketed\\] title](https://a.com/x_(y%29) — Jane Doe', '[T](https://a.com)', '[T](https://a.com)'], texts
  end
end
