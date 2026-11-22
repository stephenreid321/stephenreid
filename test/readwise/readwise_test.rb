require 'test_config'
require 'helpers/readwise_helpers'

class ReadwiseTest < ActiveSupport::TestCase
  include ReadwiseHelpers

  def to_post(...)
    with_env('READWISE_ACCESS_TOKEN' => 'token') { Readwise.to_post(...) }
  end

  test 'takes off the trackers, Substack\'s referrer on its posts and notes too, and keeps the rest' do
    {
      'https://example.com/a?utm_source=x&utm_medium=y&id=3' => 'https://example.com/a?id=3',
      'https://example.com/a?fbclid=1&gclid=2&mc_cid=3&mc_eid=4&_bhlid=5&triedRedirect=true' => 'https://example.com/a',
      'https://someone.substack.com/p/post?r=abc&s=r' => 'https://someone.substack.com/p/post?s=r',
      'https://custom.com/p/post?r=abc' => 'https://custom.com/p/post',
      'https://substack.com/@someone/note/c-1?r=abc' => 'https://substack.com/@someone/note/c-1',
      # Not elsewhere, where r may mean anything
      'https://example.com/search?r=abc' => 'https://example.com/search?r=abc',
      'https://youtu.be/abc123' => 'https://youtube.com/watch?v=abc123',
      'https://example.com/plain' => 'https://example.com/plain',
      'not a url at all' => 'not a url at all'
    }.each { |url, clean| assert_equal clean, Readwise.clean_url(url), url }
  end

  test 'lists what was archived since a time, oldest first, as the account in READWISE_ACCESS_TOKEN' do
    asked = nil
    stub_http do |stub|
      stub.get('https://readwise.io/api/v3/list') do |env|
        asked = env
        json('results' => [archived('https://example.com/new?utm_source=x', 1.hour.ago), archived('https://example.com/old', 2.days.ago),
                           archived('https://example.com/moved-before', 9.days.ago)])
      end
    end

    since = 7.days.ago
    results = with_env('READWISE_ACCESS_TOKEN' => 'token') { Readwise.archived_since(since) }

    assert_equal %w[https://example.com/old https://example.com/new], results.pluck('source_url')
    assert_equal 'Token token', asked.request_headers['Authorization']
    assert_equal({ 'location' => 'archive', 'updatedAfter' => since.iso8601 }, asked.params)
  end

  test 'fails when Readwise does' do
    stub_http { |stub| stub.get('https://readwise.io/api/v3/list') { [401, {}, ''] } }

    assert_equal 'Readwise: 401', assert_raises(RuntimeError) { Readwise.archived_since(1.day.ago, token: 'bad') }.message
  end

  test 'posts only what has not been posted, each once, whether or not what was posted still has its trackers' do
    stub_readwise(%w[https://a.com/1 https://a.com/2 https://a.com/3 https://a.com/2])

    to_post = to_post(%w[https://a.com/2?utm_source=bsky], after_newest: false)

    assert_equal %w[https://a.com/1 https://a.com/3], to_post.pluck('source_url')
  end

  test 'after the newest posted, only what was archived after it, so none lands above a later one' do
    stub_readwise(%w[https://a.com/1 https://a.com/2 https://a.com/3 https://a.com/4])

    assert_equal %w[https://a.com/4], to_post(%w[https://a.com/1 https://a.com/3], after_newest: true).pluck('source_url')
    assert_equal %w[https://a.com/1 https://a.com/2 https://a.com/3 https://a.com/4], to_post([], after_newest: true).pluck('source_url')
  end

  test 'takes the last 50 archived' do
    stub_readwise(Array.new(60) { |i| "https://a.com/#{i}" })

    to_post = to_post([])

    assert_equal 50, to_post.size
    assert_equal 'https://a.com/10', to_post.first['source_url']
  end
end
