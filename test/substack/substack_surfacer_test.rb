require 'test_config'

class SubstackSurfacerTest < ActiveSupport::TestCase
  # Its path: a stub with a pattern matches the path alone (substack.com's, with any query)
  PROFILE_PAGE = %r{\A/@stephenreid\z}

  # A page's preloads-json script, its JSON in a JSON string, as Substack's pages have it
  def preloads(data)
    %(<script id="preloads-json">#{JSON.generate(JSON.generate(data))}</script>)
  end

  def subscription(subdomain, custom_domain = nil)
    { 'publication' => { 'subdomain' => subdomain, 'custom_domain' => custom_domain } }
  end

  def post(id, at, likes: 10, **more)
    { 'id' => id, 'title' => "Post #{id}", 'canonical_url' => "https://x/p/#{id}", 'post_date' => at.utc.iso8601, 'reaction_count' => likes,
      'wordcount' => 100, 'audience' => 'everyone', 'publishedBylines' => [{ 'name' => 'Ann' }] }.merge(more.transform_keys(&:to_s))
  end

  # Each newsletter's homepage, with its free subscribers and sections, and its archive, newest first, as pages of 25
  def stub_newsletter(stub, homepage, posts, subscribers: '1,000', sections: [], section_posts: {})
    html = %(<script>window._x = {"freeSubscriberCount":"#{subscribers}"}</script>) + preloads('pub' => { 'sections' => sections })
    stub.get(homepage) { [200, {}, html] }
    stub.get("#{homepage}/api/v1/archive") do |env|
      list = env.params['section_id'] ? section_posts.fetch(env.params['section_id'].to_i) : posts
      page = env.params['cursor'].to_i
      json('posts' => list[page * 25, 25] || [], 'nextCursor' => list.size > (page + 1) * 25 ? (page + 1).to_s : nil)
    end
  end

  def fetch(token: nil)
    out = nil
    data = fetched_after { out = with_env('SUBSTACK_TOKEN' => token) { capture_io { SubstackSurfacer.fetch }.first } }
    [data['substack_surfacer'], out]
  end

  test "fetches the last 90 days' posts of each newsletter on the profile, and those it helps run, with their likes per 100 free subscribers" do
    stub_http do |stub|
      stub.get(PROFILE_PAGE) do
        [200, {}, preloads('profile' => { 'subscriptions' => [subscription('one'), subscription('two', 'two.com')], 'publicationUsers' => [subscription('mine')] })]
      end
      stub_newsletter(stub, 'https://one.substack.com', [post(1, 1.day.ago, likes: 5), post(2, 100.days.ago)])
      stub_newsletter(stub, 'https://two.com', [post(3, 2.days.ago, audience: 'only_paid', publishedBylines: [])], subscribers: '4.8K+')
      stub_newsletter(stub, 'https://mine.substack.com', [post(4, 3.days.ago)], subscribers: 'many')
    end

    data, out = fetch

    assert_match(/3 newsletters/, out)
    assert_equal 90, data['days']
    posts = data['posts'].index_by { |p| p['post_id'] }

    assert_equal [1, 3, 4], posts.keys
    assert_equal ['one', 'Ann', '1,000', 0.5, false], posts[1].values_at('newsletter_name', 'author', 'free_subscribers', 'likes_per_100_free_subscribers', 'paid')
    # 4.8K+ is 4,800 at least; a post with no byline is the newsletter's
    assert_equal ['two.com', 'two.com', true, 0.208333], posts[3].values_at('newsletter_name', 'author', 'paid', 'likes_per_100_free_subscribers')
    assert_nil posts[4]['likes_per_100_free_subscribers']
  end

  test 'pages back through the archive until a page reaches before the 90 days, and finds the posts of hidden sections too' do
    recent = Array.new(30) { |i| post(100 + i, (i + 1).hours.ago) }
    stub_http do |stub|
      stub.get(PROFILE_PAGE) { [200, {}, preloads('profile' => { 'subscriptions' => [subscription('one')] })] }
      stub_newsletter(stub, 'https://one.substack.com', recent + [post(1, 95.days.ago)] + Array.new(30) { |i| post(200 + i, (100 + i).days.ago) },
                      sections: [{ 'id' => 7, 'hide_posts_from_pub_listings' => true }, { 'id' => 8 }],
                      section_posts: { 7 => [post(9, 1.day.ago), recent.first] })
    end

    data, = fetch

    assert_equal 31, data['posts'].size
    assert_includes data['posts'].pluck('post_id'), 9
  end

  test 'signed in, reads the hidden subscriptions too, sending the cookie to Substack only' do
    cookies = {}
    stub_http do |stub|
      stub.get('https://substack.com/api/v1/user/profile/self') do |env|
        cookies[:profile] = env.request_headers['Cookie']
        json('subscriptions' => [subscription('hidden')])
      end
      stub.get('https://hidden.substack.com') do |env|
        cookies[:newsletter] = env.request_headers['Cookie']
        [301, { 'Location' => 'https://hidden.com/' }, '']
      end
      stub.get('https://hidden.com/') do |env|
        cookies[:redirected] = env.request_headers['Cookie']
        [200, {}, '']
      end
      stub.get('https://hidden.substack.com/api/v1/archive') { json('posts' => [post(1, 1.day.ago)]) }
    end

    data, = fetch(token: 'sid')

    assert_equal [1], data['posts'].pluck('post_id')
    assert_equal({ profile: 'substack.sid=sid', newsletter: nil, redirected: nil }, cookies)
  end

  test "signed out, or when the token's expired, reads the profile anyone sees" do
    stub_http do |stub|
      stub.get('https://substack.com/api/v1/user/profile/self') { [401, {}, ''] }
      stub.get(PROFILE_PAGE) { [200, {}, preloads('profile' => { 'subscriptions' => [subscription('one')] })] }
      stub_newsletter(stub, 'https://one.substack.com', [post(1, 1.day.ago)])
    end

    data, out = fetch(token: 'expired')

    assert_match(/Signed in, no profile/, out)
    assert_equal [1], data['posts'].pluck('post_id')
  end

  test 'waits as long as Substack says when it rate-limits, and backs off when it says nothing' do
    archive = in_turn([429, { 'Retry-After' => '5' }, ''], [429, {}, ''], json('posts' => [post(1, 1.day.ago)]))
    stub_http do |stub|
      stub.get(PROFILE_PAGE) { [200, {}, preloads('profile' => { 'subscriptions' => [subscription('one')] })] }
      stub.get('https://one.substack.com') { [200, {}, ''] }
      stub.get('https://one.substack.com/api/v1/archive') { |env| archive.call(env) }
    end

    data, = fetch

    assert_equal [1], data['posts'].pluck('post_id')
    assert_equal [5, 4], OutsideServices.retry_waits.map(&:round)
  end

  test 'keeps the posts fetched last time when most newsletters fail, as when Cloudflare turns it away' do
    stub_http do |stub|
      stub.get(PROFILE_PAGE) { [200, {}, preloads('profile' => { 'subscriptions' => %w[a b c].map { |s| subscription(s) } })] }
      stub_newsletter(stub, 'https://a.substack.com', [post(1, 1.day.ago)])
      %w[b c].each do |s|
        stub.get("https://#{s}.substack.com") { [403, {}, 'Cloudflare'] }
        stub.get("https://#{s}.substack.com/api/v1/archive") { [403, {}, 'Cloudflare'] }
      end
    end

    error = assert_raises(SubstackSurfacer::Error) { capture_io { with_fetched { SubstackSurfacer.fetch } } }

    assert_equal '2 of 3 newsletters failed', error.message
  end

  test "for the page: each post with what it's sorted by, best first, leaving out those skipped" do
    posts = [post(1, 2.days.ago).merge('newsletter_url' => 'https://a.com', 'free_subscribers' => '1K+', 'likes_per_100_free_subscribers' => 0.123456),
             post(2, 1.day.ago).merge('newsletter_url' => 'https://a.com', 'free_subscribers' => nil, 'likes_per_100_free_subscribers' => nil),
             post(3, 1.day.ago).merge('newsletter_url' => 'https://b.com', 'free_subscribers' => '10', 'likes_per_100_free_subscribers' => 9.996),
             post(4, 1.day.ago).merge('newsletter_url' => SubstackSurfacer::SKIPPED.first)]
    page = with_fetched(substack_surfacer: { 'fetched_at' => 'now', 'days' => 90, 'posts' => posts }) { SubstackSurfacer.for_template }

    assert_equal [3, 1, 2], page['posts'].pluck('id')
    assert_equal([['10.0', '10', 1], ['0.123', '1K', 2], [nil, nil, 2]],
                 page['posts'].map { |p| p.values_at('likes_per_100_free_subscribers_shown', 'free_subscribers_shown', 'newsletter_posts') })
    assert_equal [10.0, 1000.0, -1], page['posts'].pluck('free_subscribers_sort')
  end

  test 'shows numbers to three significant figures, and reads the subscriber counts Substack shows' do
    { 225.4 => '225', 71.94 => '71.9', 0.41666 => '0.417', 9.996 => '10.0', 0 => '0', 1234.5 => '1230' }.each do |n, shown|
      assert_equal shown, SubstackSurfacer.significant_figures(n), n
    end
    { '1,234' => 1234.0, '3K+' => 3000.0, '4.8k' => 4800.0, '1M+' => 1_000_000.0, 'lots' => nil, nil => nil }.each do |text, n|
      n.nil? ? assert_nil(SubstackSurfacer.subscriber_number(text), text.inspect) : assert_equal(n, SubstackSurfacer.subscriber_number(text), text.inspect)
    end
  end
end
