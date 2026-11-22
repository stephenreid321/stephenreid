require 'test_config'

class SubstackPostTest < ActiveSupport::TestCase
  API = 'https://stephenreid.substack.com/api/v1'.freeze
  ENV_VARS = { 'SUBSTACK_TOKEN' => 'sid', 'SUBSTACK_PUBLICATION_URL' => 'https://stephenreid.substack.com' }.freeze

  def archive_row(id)
    { 'id' => id, 'slug' => "post-#{id}", 'title' => "Post #{id}", 'post_date' => "2026-0#{id}-01T00:00:00Z", 'reaction_count' => 5 * id }
  end

  # The archive, two posts a page, and each post's body, as Substack's API answers them. Returns the slugs whose
  # bodies were fetched, in turn
  def stub_publication(ids, bodies: ids.to_h { |id| ["post-#{id}", ["<p>Body #{id}</p>"]] })
    fetched = []
    pages = ids.each_slice(2).to_a
    answers = bodies.transform_values { |list| in_turn(*list.map { |b| b.is_a?(Array) ? b : json('body_html' => b, 'publication_id' => 9) }) }
    stub_http do |stub|
      stub.get("#{API}/archive") do |env|
        assert_equal ['new', '25', 'substack.sid=sid'], [env.params['sort'], env.params['limit'], env.request_headers['Cookie']]
        i = env.params['cursor'].to_i
        json('posts' => (pages[i] || []).map { |id| archive_row(id) }, 'nextCursor' => (pages[i + 1] ? (i + 1).to_s : nil))
      end
      bodies.each_key do |slug|
        stub.get("#{API}/posts/#{slug}") do |env|
          fetched << slug
          answers[slug].call(env)
        end
      end
    end
    fetched
  end

  def import(existing = [])
    fetched_after(substack_posts: existing) do
      Substack.stub(:sleep, nil) { with_env(ENV_VARS) { capture_io { SubstackPost.import } } }
    end['substack_posts']
  end

  test 'keeps each post in the archive, oldest first, with its body, but not its likes' do
    stub_publication([3, 2, 1])

    posts = import

    assert_equal [1, 2, 3], posts.pluck('post_id')
    assert_equal ['post-1', 'Post 1', '<p>Body 1</p>', 9], posts.first.values_at('slug', 'title', 'body_html', 'publication_id')
    refute posts.first.key?('reaction_count')
  end

  test 'keeps the bodies it fetched before, fetching only those of new posts, and drops posts gone from the archive' do
    fetched = stub_publication([2, 1], bodies: { 'post-2' => ['<p>New</p>'] })

    posts = import([{ 'post_id' => 1, 'body_html' => '<p>Kept</p>' }, { 'post_id' => 99, 'body_html' => '<p>Gone</p>' }])

    assert_equal %w[post-2], fetched
    assert_equal({ 1 => '<p>Kept</p>', 2 => '<p>New</p>' }, posts.to_h { |p| [p['post_id'], p['body_html']] })
  end

  test 'asks again for a body Substack sent without one, or failed to send' do
    fetched = stub_publication([1], bodies: { 'post-1' => ['', *[[500, {}, 'oops']] * 3, '<p>At last</p>'] })

    assert_equal '<p>At last</p>', import.first['body_html']
    # Once with no body, three times the connection tries before it gives up, and once more
    assert_equal 5, fetched.size
  end

  test 'writes a post as markdown: its title and date, its images at their largest, and its mentions named' do
    html = '<div class="image2-inset"><picture><source srcset="x.webp"><img src="small.jpg" srcset="a.jpg 424w, b.jpg 848w, c.jpg 1456w"></picture>' \
           '<div class="image-link-expand">expand</div></div>' \
           '<p>Thanks <span class="mention-wrap" data-attrs="{&quot;name&quot;:&quot;Ann Lee&quot;,&quot;id&quot;:42}"></span>!</p>'
    post = SubstackPost.new('title' => 'A <b>post</b>', 'post_date' => '2026-01-01', 'body_html' => html)

    assert_equal "# A \\<b\\>post\\</b\\>, 2026-01-01\n ![](c.jpg)\n\nThanks [Ann Lee](https://open.substack.com/users/42-ann-lee)!\n\n", post.to_markdown
    assert_equal '', SubstackPost.new('title' => 'Empty').to_markdown
  end
end
