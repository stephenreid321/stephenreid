require 'test_config'

class SubstackNoteTest < ActiveSupport::TestCase
  API = 'https://stephenreid.substack.com/api/v1'.freeze
  ENV_VARS = { 'SUBSTACK_TOKEN' => 'sid', 'SUBSTACK_PUBLICATION_URL' => 'stephenreid.substack.com/' }.freeze

  # A note as Substack's API lists it, with what the site doesn't read too
  def raw_note(key, body: "Note #{key}", attachments: [], **more)
    { 'entity_key' => key, 'context' => { 'timestamp' => "2026-11-0#{key[-1]}T10:00:00Z", 'tracking' => 'changes' },
      'comment' => { 'handle' => 'stephenreid', 'body' => body, 'reaction_count' => 3, 'restacks' => 9, 'attachments' => attachments } }.merge(more)
  end

  LINK = { 'type' => 'link', 'id' => 'tracking', 'linkMetadata' => { 'url' => 'https://example.com', 'title' => 'Example', 'host' => 'example.com',
                                                                     'image' => 'https://img/e.jpg', 'favicon' => 'x' } }.freeze
  IMAGE = { 'type' => 'image', 'imageUrl' => 'https://img/1.jpg', 'imageWidth' => 900 }.freeze
  QUOTE = { 'type' => 'post', 'postSelection' => { 'text' => "First line\nSecond line" }, 'postSelectionTheme' => { 'name' => 'dark' },
            'post' => { 'title' => 'A post', 'canonical_url' => 'https://a.substack.com/p/a-post', 'publishedBylines' => [{ 'name' => 'Ann' }, { 'name' => 'Bo' }] } }.freeze

  def import(pages)
    stub_http do |stub|
      stub.get("#{API}/notes") do |env|
        cursor = env.params['cursor']
        page = pages[cursor ? cursor.to_i : 0]
        json('items' => page, 'nextCursor' => (pages[(cursor.to_i + 1)] ? (cursor.to_i + 1).to_s : nil))
      end
    end
    written = nil
    with_env(ENV_VARS) { capture_io { written = fetched_after { SubstackNote.import } } }
    written['substack_notes']
  end

  test 'keeps of each note, page after page, only what the site reads, and of each attachment only what it shows' do
    notes = import([[raw_note('c-2', attachments: [LINK])], [raw_note('c-1')]])

    assert_equal %w[c-1 c-2], notes.pluck('entity_key')
    assert_equal({ 'entity_key' => 'c-2', 'body' => 'Note c-2', 'published_at' => '2026-11-02T10:00:00Z',
                   'primary_link' => 'https://substack.com/@stephenreid/note/c-2', 'reaction_count' => 3, 'comment_author_handle' => 'stephenreid',
                   'attachments' => [{ 'type' => 'link', 'linkMetadata' => LINK['linkMetadata'].except('favicon') }] }, notes.last)
  end

  test 'a note about a post links to the post, with its cover and publication' do
    post = { 'title' => 'P', 'canonical_url' => 'https://pub.com/p/p', 'subtitle' => 'Sub', 'reaction_count' => 0, 'cover_image' => { 'url' => 'https://img/c.jpg' } }
    note = import([[raw_note('c-1', post: post, publication: { 'name' => 'Pub', 'custom_domain' => 'pub.com', 'logoUrl' => 'https://img/l.png' })]]).first

    assert_equal ['https://pub.com/p/p', 'https://img/c.jpg', 0, 'https://img/l.png'],
                 note.values_at('primary_link', 'post_cover_image_url', 'post_reaction_count', 'publication_logo_url')
  end

  test 'writes each note as markdown, with its publication, post, quotes and attachments' do
    attachments = [LINK, IMAGE, QUOTE,
                   { 'type' => 'video', 'mediaUpload' => { 'name' => 'Clip', 'mux_playback_id' => 'mux1', 'poster' => 'https://img/p.jpg' } },
                   { 'type' => 'comment', 'comment' => { 'body' => "  A  quoted\ncomment ", 'id' => 7, 'user' => { 'handle' => 'ann' } } },
                   { 'type' => 'publication_recommendation', 'publicationRecommendation' => { 'recommendedPublication' => { 'name' => 'Rec', 'subdomain' => 'rec' } } },
                   { 'type' => 'link', 'linkMetadata' => { 'url' => 'https://youtube.com/watch?v=1', 'title' => '- YouTube', 'host' => 'youtube.com' } },
                   { 'type' => 'poll' }]
    note = SubstackNote.new(import([[raw_note('c-1', attachments: attachments, publication: { 'name' => 'Pub', 'subdomain' => 'pub' }, 'parentComments' => [{}, {}])]]).first)

    assert_equal <<~MARKDOWN, note.to_markdown
      ## 2026-11-01T10:00:00Z

      - **Note ID:** `c-1`
      - **Link:** https://substack.com/@stephenreid/note/c-1
      - **Likes:** 3
      - **Publication:** [Pub](https://pub.substack.com)

      > **From:** [A post](https://a.substack.com/p/a-post)
      > First line
      > Second line
      > — Ann and Bo


      Note c-1

      **Attachments:**

      ![](https://img/e.jpg)
      [Example](https://example.com)
      ![](https://img/1.jpg)
      ![](https://img/p.jpg)
      - **Video:** [Clip](https://stream.mux.com/mux1.m3u8)
      [Quoted comment](https://substack.com/@ann/note/c-7)
      > A quoted comment
      [Rec](https://rec.substack.com)
      [youtube.com](https://youtube.com/watch?v=1)
      - `poll`


      _(2 parent comment(s))_


      * * *
    MARKDOWN
  end

  test 'reads notes as they were kept before, with their attachments as JSON in a string' do
    old = { 'entity_key' => 'c-1', 'body' => 'Hi', 'published_at' => '2026-01-01', 'post_title' => '', 'reaction_count' => nil,
            'attachments_json' => JSON.generate([IMAGE]), 'quote_selections_json' => '' }
    note = SubstackNote.new(old)

    assert_equal ['https://img/1.jpg'], note.image_urls_for_gallery
    assert_includes note.to_markdown, "**Attachments:**\n\n![](https://img/1.jpg)\n"
    refute_includes note.to_markdown, 'Likes'
  end

  test "the homepage's gallery has the newest notes' images, then their post's cover, each once, resized on Substack's CDN" do
    notes = [{ 'entity_key' => 'c-1', 'published_at' => '2026-01-01', 'primary_link' => 'https://s/1', 'attachments' => [IMAGE] },
             { 'entity_key' => 'c-2', 'published_at' => '2026-01-02', 'primary_link' => 'https://s/2', 'post_cover_image_url' => 'https://img/1.jpg',
               'attachments' => [IMAGE, IMAGE.merge('imageUrl' => 'https://substackcdn.com/image/fetch/w_1456/https%3A%2F%2Fimg%2F2.jpg')] },
             { 'entity_key' => 'c-3', 'published_at' => '2026-01-03', 'attachments' => [IMAGE] }]
    items = with_fetched(substack_notes: notes) { SubstackNote.recent_gallery_items(limit: 3) }

    cdn = ->(url) { "https://substackcdn.com/image/fetch/w_480,c_limit,f_webp,q_auto:good/#{URI.encode_www_form_component(url)}" }

    assert_equal([[cdn.call('https://img/1.jpg'), 'https://s/2'], [cdn.call('https://img/2.jpg'), 'https://s/2'], [cdn.call('https://img/1.jpg'), 'https://s/1']],
                 items.map { |item| item.values_at(:image_url, :note_url) })
  end

  test 'is skipped without SUBSTACK_TOKEN and SUBSTACK_PUBLICATION_URL' do
    out = with_env('SUBSTACK_TOKEN' => nil) { capture_io { SubstackNote.import }.first }

    assert_match(/API import skipped/, out)
  end

  test "fails, keeping the notes it had, when Substack's API does" do
    stub_http { |stub| stub.get("#{API}/notes") { [403, {}, 'Cloudflare'] } }

    kept = [{ 'entity_key' => 'c-1' }]
    with_fetched(substack_notes: kept) do |fetched|
      error = assert_raises(RuntimeError) { with_env(ENV_VARS) { SubstackNote.import } }

      assert_match(/HTTP 403: Cloudflare/, error.message)
      assert_equal kept, fetched['substack_notes']
    end
  end
end
