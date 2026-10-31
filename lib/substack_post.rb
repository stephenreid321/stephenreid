# A post on the Substack publication, from data/fetched/substack_posts.json (rake data:substack)
class SubstackPost
  FIELDS = %w[
    post_id publication_id slug title subtitle description post_date canonical_url post_type audience podcast_url
    cover_image_url wordcount truncated_body_text body_html
  ].freeze

  attr_reader(*FIELDS)

  def initialize(attributes)
    attributes.each { |name, value| instance_variable_set(:"@#{name}", value) if FIELDS.include?(name.to_s) }
  end

  def to_markdown
    html = body_html.to_s
    return '' if html.blank?

    doc = Nokogiri::HTML(
      "<h1>#{CGI.escapeHTML(title.to_s)}, #{CGI.escapeHTML(post_date.to_s)}</h1>#{html.gsub(/<source.*?>/, '')}"
    )
    doc.search('div.image2-inset').each do |tag|
      tag.replace(tag.children)
    end
    doc.search('picture').each do |tag|
      tag.replace(tag.children)
    end
    doc.search('div.image-link-expand').remove
    doc.search('img').each do |tag|
      tag['src'] = tag['srcset'].split[-2] if tag['srcset']
    end
    Substack.expand_mentions!(doc)

    ReverseMarkdown.convert(doc.to_html.gsub('<div></div>', ''))
  end

  class << self
    # Oldest first
    def all
      Fetched.read(:substack_posts).map { |attributes| new(attributes) }.sort_by(&:post_id)
    end

    # Publication /api/v1/archive → data/fetched/substack_posts.json, keeping the bodies it fetched before. Same env as
    # SubstackNote: SUBSTACK_TOKEN, SUBSTACK_PUBLICATION_URL.
    def import
      unless Substack.api_sync_enabled?
        puts 'ℹ️  Substack post import skipped: set SUBSTACK_TOKEN and SUBSTACK_PUBLICATION_URL.'
        return
      end

      conn = Substack.http_client
      base_api = Substack.base_api_url

      all_raw = []
      offset = 0
      page_size = 12
      loop do
        page = Substack.fetch_archive_page(conn: conn, base_api: base_api, offset: offset, limit: page_size)
        break if page.empty?

        all_raw.concat(page)
        offset += page.size
      end

      # Posts no longer in the archive drop out
      existing = Fetched.read(:substack_posts).index_by { |post| post['post_id'] }
      posts = all_raw.reverse.filter_map do |archive_row|
        post_attributes(conn: conn, base_api: base_api, archive_row: archive_row, existing: existing[archive_row['id']])
      end
      posts = posts.uniq { |post| post[:post_id] }
      Fetched.write(:substack_posts, posts)

      puts "🗄️  Substack post import: #{posts.size} post(s)"
    end

    def markdown_export(limit: nil)
      n = limit.to_i
      posts = all
      posts = posts.last(n) if n.positive?
      posts.map(&:to_markdown).reject(&:blank?).join("\n")
    end

    private

    def post_attributes(conn:, base_api:, archive_row:, existing:)
      pid = archive_row['id']
      return if pid.nil?

      body_html = existing && existing['body_html'].presence
      detail = (Substack.fetch_post_detail(conn: conn, base_api: base_api, slug: archive_row['slug']) unless body_html)

      raw = archive_row.merge(detail || {})
      raw['body_html'] = body_html if body_html

      # Not its likes, comments and restacks, which change from one fetch to the next and the site doesn't show
      {
        post_id: pid,
        publication_id: raw['publication_id'],
        slug: raw['slug'].to_s,
        title: raw['title'].to_s,
        subtitle: raw['subtitle'].to_s,
        description: raw['description'].to_s,
        post_date: raw['post_date'].to_s,
        canonical_url: raw['canonical_url'].to_s,
        post_type: raw['type'].to_s,
        audience: raw['audience'].to_s,
        podcast_url: raw['podcast_url'].to_s,
        cover_image_url: raw['cover_image'].to_s,
        wordcount: raw['wordcount'],
        truncated_body_text: raw['truncated_body_text'].to_s,
        body_html: raw['body_html'].to_s
      }
    end
  end
end
