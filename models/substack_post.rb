class SubstackPost
  include Mongoid::Document
  include Mongoid::Timestamps

  # Keep in sync with SubstackNote::USER_AGENT.
  USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.2 Safari/605.1.15'

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
      unless api_sync_enabled?
        puts 'ℹ️  Substack post import skipped: set SUBSTACK_TOKEN and SUBSTACK_PUBLICATION_URL.'
        return { api_sync: false, sync_created: 0 }
      end

      imported = 0

      token = ENV['SUBSTACK_TOKEN']
      publication_url = ENV['SUBSTACK_PUBLICATION_URL']
      base_api = "#{normalize_publication_url(publication_url).chomp('/')}/api/v1"
      http = HTTP.headers(
        'Cookie' => "substack.sid=#{token}",
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'User-Agent' => USER_AGENT
      )

      all_raw = []
      offset = 0
      page_size = 50
      loop do
        page = fetch_archive_page(http: http, base_api: base_api, offset: offset, limit: page_size)
        break if page.empty?

        all_raw.concat(page)
        break if page.size < page_size

        offset += page_size
      end

      seen_ids = []

      all_raw.reverse_each do |archive_row|
        next if archive_row['id'].nil?

        seen_ids << archive_row['id']
        import_post(http: http, base_api: base_api, archive_row: archive_row)
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

    def api_sync_enabled?
      ENV['SUBSTACK_TOKEN'].present? && ENV['SUBSTACK_PUBLICATION_URL'].present?
    end

    def normalize_publication_url(url)
      u = url.to_s.strip
      u.start_with?('http://', 'https://') ? u : "https://#{u}"
    end

    def fetch_archive_page(http:, base_api:, offset:, limit:)
      response = http.get("#{base_api}/archive?limit=#{limit}&offset=#{offset}")
      raise "HTTP #{response.status}: #{response.body.to_s[0, 200]}" unless response.status.success?

      arr = JSON.parse(response.body.to_s)
      arr.is_a?(Array) ? arr : []
    end

    def fetch_post_detail(http:, base_api:, slug:, max_attempts: 3)
      s = slug.to_s.strip
      return nil if s.empty?

      path = "#{base_api}/posts/#{Rack::Utils.escape_path(s)}"
      last_detail = nil
      last_error = nil

      max_attempts.times do |attempt|
        response = http.get(path)
        unless response.status.success?
          last_error = "HTTP #{response.status}"
          sleep(0.5 * (attempt + 1)) if attempt < max_attempts - 1
          next
        end

        detail = JSON.parse(response.body.to_s)
        last_detail = detail
        return detail if detail['body_html'].to_s.present?

        last_error = 'body_html blank'
        sleep(0.5 * (attempt + 1)) if attempt < max_attempts - 1
      rescue JSON::ParserError => e
        last_error = "JSON parse error: #{e.message}"
        sleep(0.5 * (attempt + 1)) if attempt < max_attempts - 1
      end

      if last_detail && last_detail['body_html'].to_s.blank?
        puts "⚠️  Substack post detail: body_html still blank after #{max_attempts} attempt(s) (slug=#{s})"
      elsif last_error
        puts "⚠️  Substack post detail: failed after #{max_attempts} attempt(s) (slug=#{s}, error=#{last_error})"
      end

      last_detail
    end

    def safe_json(obj)
      return '' if obj.nil?

      JSON.generate(obj)
    rescue JSON::GeneratorError
      ''
    end

    def import_post(http:, base_api:, archive_row:)
      pid = archive_row['id']
      return if pid.nil?

      record = find_or_initialize_by(post_id: pid)
      detail =
        (fetch_post_detail(http: http, base_api: base_api, slug: archive_row['slug']) if record.new_record? || record.body_html.blank?)

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
        reactions_json: safe_json(raw['reactions']),
        raw_json: safe_json(raw)
      )
      record.save!
    end
  end
end
