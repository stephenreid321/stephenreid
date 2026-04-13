class SubstackPost
  include Mongoid::Document
  include Mongoid::Timestamps

  field :post_id, type: Integer
  field :publication_id, type: Integer
  field :slug, type: String
  field :title, type: String
  field :subtitle, type: String
  field :description, type: String
  field :post_date, type: String
  field :canonical_url, type: String
  field :post_type, type: String
  field :audience, type: String
  field :podcast_url, type: String
  field :cover_image_url, type: String
  field :reaction_count, type: Integer
  field :comment_count, type: Integer
  field :restacks, type: Integer
  field :wordcount, type: Integer
  field :truncated_body_text, type: String
  field :body_html, type: String
  field :reactions_json, type: String
  field :raw_json, type: String

  index({ post_id: 1 }, { unique: true })

  validates_uniqueness_of :post_id

  def self.admin_fields
    {
      post_id: :number,
      publication_id: :number,
      slug: :text,
      title: :text,
      subtitle: :text_area,
      description: :text_area,
      post_date: :text,
      canonical_url: :url,
      post_type: :text,
      audience: :text,
      podcast_url: :url,
      cover_image_url: :url,
      reaction_count: :number,
      comment_count: :number,
      restacks: :number,
      wordcount: :number,
      truncated_body_text: :text_area,
      body_html: :text_area,
      reactions_json: :text_area,
      raw_json: :text_area
    }
  end

  def to_markdown
    html = body_html.to_s
    return '' if html.blank?

    doc = Nokogiri::HTML(
      "<h1>#{Rack::Utils.escape_html(title.to_s)}, #{Rack::Utils.escape_html(post_date.to_s)}</h1>#{html.gsub(/<source.*?>/, '')}"
    )
    doc.search('div.image2-inset').each do |tag|
      tag.replace(tag.children)
    end
    doc.search('picture').each do |tag|
      tag.replace(tag.children)
    end
    doc.search('div.image-link-expand').remove
    doc.search('img').each do |tag|
      tag['src'] = tag['srcset'].split(' ')[-2] if tag['srcset']
    end

    ReverseMarkdown.convert(doc.to_html.gsub('<div></div>', ''))
  end

  class << self
    # Publication /api/v1/archive → Mongo. Same env as SubstackNote: SUBSTACK_TOKEN, SUBSTACK_PUBLICATION_URL.
    def import
      unless Substack.api_sync_enabled?
        puts 'ℹ️  Substack post import skipped: set SUBSTACK_TOKEN and SUBSTACK_PUBLICATION_URL.'
        return { api_sync: false, sync_created: 0 }
      end

      imported = 0

      conn = Substack.http_client
      base_api = Substack.base_api_url

      all_raw = []
      offset = 0
      page_size = 50
      loop do
        page = Substack.fetch_archive_page(conn: conn, base_api: base_api, offset: offset, limit: page_size)
        break if page.empty?

        all_raw.concat(page)
        break if page.size < page_size

        offset += page_size
      end

      seen_ids = []

      all_raw.reverse_each do |archive_row|
        next if archive_row['id'].nil?

        seen_ids << archive_row['id']
        import_post(conn: conn, base_api: base_api, archive_row: archive_row)
        imported += 1
      end

      SubstackPost.where(:post_id.nin => seen_ids).delete_all if seen_ids.any?

      puts "🗄️  Substack post import: #{imported} post(s)"

      { api_sync: true, sync_created: imported }
    end

    def markdown_export(limit: nil)
      n = limit.to_i
      scope = desc(:post_id)
      scope = scope.limit(n) if n.positive?
      scope.to_a.reverse.map(&:to_markdown).reject(&:blank?).join("\n")
    end

    private

    def import_post(conn:, base_api:, archive_row:)
      pid = archive_row['id']
      return if pid.nil?

      record = find_or_initialize_by(post_id: pid)
      detail =
        (Substack.fetch_post_detail(conn: conn, base_api: base_api, slug: archive_row['slug']) if record.new_record? || record.body_html.blank?)

      raw = archive_row.merge(detail || {})
      raw['body_html'] = record.body_html if record.persisted? && record.body_html.present?

      record.assign_attributes(
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
        reaction_count: raw['reaction_count'],
        comment_count: raw['comment_count'],
        restacks: raw['restacks'],
        wordcount: raw['wordcount'],
        truncated_body_text: raw['truncated_body_text'].to_s,
        body_html: raw['body_html'].to_s,
        reactions_json: Substack.safe_json(raw['reactions']),
        raw_json: Substack.safe_json(raw)
      )
      record.save!
    end
  end
end
