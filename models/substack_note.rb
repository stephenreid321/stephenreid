class SubstackNote
  include Mongoid::Document
  include Mongoid::Timestamps

  # IDs and counts: Substack’s JSON uses JSON numbers, so JSON.parse yields Integer in Ruby.
  # (Exported CSV shows digits as strings — that’s CSV, not the API.) Blank API fields use fetch(..., '')
  # in flatten_raw_note; coerce_integer maps those to nil.
  INTEGER_TYPES = %w[
    post_id post_restacks post_reaction_count post_comment_count publication_id
    comment_id comment_user_id reaction_count restacks children_count media_clip_id
  ].freeze

  STRING_TYPES = %w[
    entity_key body published_at primary_link feed_item_type context_type context_json
    post_title post_slug post_canonical_url post_date
    post_restacked post_subtitle post_description post_cover_image_url
    publication_name publication_subdomain publication_custom_domain publication_logo_url
    comment_author_handle comment_author_name
    comment_photo_url comment_bio parent_comment_id
    quote_selections_json reactions_json restacked
    edited_at attachments_json body_json parent_comments_json
  ].freeze

  BASE_COLUMNS = (STRING_TYPES + INTEGER_TYPES).freeze

  # Admin UI for STRING_TYPES (default :text). INTEGER_TYPES use :number.
  URL_TYPES = %w[
    primary_link post_canonical_url post_cover_image_url publication_logo_url comment_photo_url
  ].freeze

  TEXT_AREA_TYPES = %w[
    comment_bio context_json post_subtitle post_description body quote_selections_json reactions_json
    attachments_json body_json parent_comments_json
  ].freeze

  BASE_COLUMNS.each do |name|
    field name.to_sym, type: INTEGER_TYPES.include?(name) ? Integer : String
  end

  field :raw_json, type: String

  validates_uniqueness_of :entity_key

  def self.admin_fields
    fields = {}
    STRING_TYPES.each do |name|
      fields[name.to_sym] =
        if URL_TYPES.include?(name)
          :url
        elsif TEXT_AREA_TYPES.include?(name)
          :text_area
        else
          :text
        end
    end
    INTEGER_TYPES.each { |name| fields[name.to_sym] = :number }
    fields
  end

  # Each type maps to `render_<type>_attachment` below.
  ATTACHMENT_TYPES = %w[image video link publication comment post].freeze

  def to_markdown
    self.class.send(:markdown_for_note, self)
  end

  # Public note URL on Substack (homepage gallery links).
  def gallery_note_url
    u = primary_link.to_s.strip
    return u if u.present?

    h = comment_author_handle.to_s.strip
    k = entity_key.to_s.strip
    h.present? && k.present? ? "https://substack.com/@#{h}/note/#{k}" : ''
  end

  # Image attachment URLs plus post cover when present, in feed order (deduped).
  def image_urls_for_gallery
    parsed = JSON.parse(attachments_json.to_s.presence || '[]')
    urls = (parsed.is_a?(Array) ? parsed : []).filter_map do |att|
      next unless att.is_a?(Hash) && att['type'] == 'image'

      (att['imageUrl'] || att['url']).to_s.strip.presence
    end
    urls.uniq!
    pc = post_cover_image_url.to_s.strip
    urls << pc if pc.present? && !urls.include?(pc)
    urls
  rescue JSON::ParserError
    []
  end

  class << self
    # Substack API → Mongo. Env: SUBSTACK_TOKEN, SUBSTACK_PUBLICATION_URL.
    def import
      unless Substack.api_sync_enabled?
        puts 'ℹ️  API import skipped: set SUBSTACK_TOKEN and SUBSTACK_PUBLICATION_URL.'
        return { api_sync: false, sync_created: 0 }
      end

      delete_all
      imported = 0

      conn = Substack.http_client
      base_api = Substack.base_api_url

      all_raw = []
      cursor = nil
      loop do
        data = Substack.fetch_notes_page(conn: conn, base_api: base_api, cursor: cursor)
        all_raw.concat(data['items'] || [])

        cursor = data['nextCursor']
        break if cursor.to_s.empty?
      end

      all_raw.reverse_each do |raw|
        import_note(flatten_raw_note(raw))
        imported += 1
      end

      puts "🗄️  API import: #{imported} SubstackNote(s)"

      { api_sync: true, sync_created: imported }
    end

    def markdown_export(limit: nil)
      n = limit.to_i
      scope = desc(:published_at)
      scope = scope.limit(n) if n.positive?
      scope.map(&:to_markdown).join
    end

    # Newest notes first; flattens images (+ post covers) into up to +limit+ cells.
    def recent_gallery_items(limit: 20)
      max_items = (n = limit.to_i).positive? ? n : 20
      items = []
      desc(:published_at).each do |note|
        url = note.gallery_note_url
        next if url.blank?

        note.image_urls_for_gallery.each do |img|
          items << { image_url: img, note_url: url, published_at: note.published_at.to_s }
          return items if items.size >= max_items
        end
      end
      items
    end

    private

    def import_note(flat)
      key = flat['entity_key'].to_s.strip
      return if key.empty?

      attrs = BASE_COLUMNS.to_h do |name|
        [name.to_sym, INTEGER_TYPES.include?(name) ? coerce_integer(flat[name]) : flat[name].to_s]
      end
      attrs[:entity_key] = key
      attrs[:raw_json] = flat['raw_json'].to_s if flat['raw_json'].present?

      create!(attrs)
    end

    def coerce_integer(value)
      return nil if value.nil?
      return value if value.is_a?(Integer)
      return Integer(value) if value.is_a?(Numeric)

      s = value.to_s.strip
      return nil if s.empty?

      Integer(s, 10)
    rescue ArgumentError, TypeError
      nil
    end

    def truncated_json(obj, max = 500)
      s = Substack.safe_json(obj)
      s.length > max ? "#{s[0, max]}…" : s
    end

    def primary_link(raw)
      post_url = raw.dig('post', 'canonical_url')
      return post_url if post_url

      key = raw['entity_key']
      handle = raw.dig('comment', 'handle')
      return '' unless key.present? && handle.present?

      "https://substack.com/@#{handle}/note/#{key}"
    end

    def post_cover_url(post)
      return '' unless post.is_a?(Hash)

      if (cover = post['cover_image'] || post['coverImage'])
        cover = cover['url'] || cover['URL'] if cover.is_a?(Hash)
        return cover.to_s
      end

      (post['cover_image_url'] || post['coverImageUrl']).to_s
    end

    def extract_quote_selections(attachments)
      return [] unless attachments.is_a?(Array)

      attachments.filter_map do |att|
        next unless att['type'] == 'post'

        selection = att['postSelection']
        next unless selection.is_a?(Hash)

        text = selection['text'].to_s
        next if text.empty?

        post = att['post'] || {}
        theme = att.dig('postSelectionTheme', 'name').to_s

        { 'text' => text, 'attribution' => format_bylines(post['publishedBylines']),
          'post_title' => post['title'].to_s, 'post_url' => post['canonical_url'].to_s,
          'theme' => theme }
      end
    end

    def format_bylines(bylines)
      return '' unless bylines.is_a?(Array)

      bylines.filter_map { |b| b['name'].presence }.join(' and ')
    end

    def post_fields(post)
      return {} unless post

      {
        'post_id' => post['id'],
        'post_title' => post['title'].to_s,
        'post_slug' => post['slug'].to_s,
        'post_canonical_url' => post['canonical_url'].to_s,
        'post_date' => post['post_date'].to_s,
        'post_restacks' => post.fetch('restacks', ''),
        'post_restacked' => post.key?('restacked') ? post['restacked'].to_s : '',
        'post_reaction_count' => post.fetch('reaction_count', ''),
        'post_comment_count' => post.fetch('comment_count', ''),
        'post_subtitle' => post['subtitle'].to_s,
        'post_description' => post['description'].to_s,
        'post_cover_image_url' => post_cover_url(post)
      }
    end

    def publication_fields(pub)
      return {} unless pub

      {
        'publication_id' => pub['id'],
        'publication_name' => pub['name'].to_s,
        'publication_subdomain' => pub['subdomain'].to_s,
        'publication_custom_domain' => pub['custom_domain'].to_s,
        'publication_logo_url' => (pub['logo_url'] || pub['logoUrl']).to_s
      }
    end

    def comment_fields(comment)
      return {} unless comment

      {
        'comment_id' => comment['id'],
        'comment_author_handle' => comment['handle'].to_s,
        'comment_author_name' => comment['name'].to_s,
        'comment_user_id' => comment.fetch('user_id', ''),
        'comment_photo_url' => (comment['photo_url'] || comment['author_photo_url']).to_s,
        'comment_bio' => comment['bio'].to_s,
        'parent_comment_id' => (comment['parent_comment_id'] || comment['parent_id'] || comment.dig('parent_comment', 'id')).to_s,
        'body' => comment['body'].to_s,
        'reaction_count' => comment.fetch('reaction_count', ''),
        'reactions_json' => Substack.safe_json(comment['reactions']),
        'restacks' => comment.fetch('restacks', ''),
        'restacked' => comment.key?('restacked') ? comment['restacked'].to_s : '',
        'children_count' => comment.fetch('children_count', ''),
        'edited_at' => comment['edited_at'].to_s,
        'media_clip_id' => comment.fetch('media_clip_id', ''),
        'attachments_json' => Substack.safe_json(comment['attachments']),
        'body_json' => Substack.safe_json(comment['body_json'])
      }
    end

    def flatten_raw_note(raw)
      comment = raw['comment']
      post = raw['post']
      pub = raw['publication']
      ctx = raw['context']

      published_at = ctx&.dig('timestamp') || comment&.dig('date') || post&.dig('post_date') || ''
      quote_selections = extract_quote_selections(comment&.dig('attachments'))

      row = {
        'entity_key' => raw['entity_key'].to_s,
        'feed_item_type' => raw['type'].to_s,
        'context_type' => ctx&.dig('type').to_s,
        'context_json' => ctx ? Substack.safe_json(ctx) : '',
        'published_at' => published_at.to_s,
        'primary_link' => primary_link(raw),
        'post_id' => post ? post['id'] : comment&.dig('post_id'),
        'quote_selections_json' => quote_selections.empty? ? '' : Substack.safe_json(quote_selections),
        'parent_comments_json' => raw['parentComments'] ? Substack.safe_json(raw['parentComments']) : ''
      }

      row.merge!(post_fields(post))
      row.merge!(publication_fields(pub))
      row.merge!(comment_fields(comment))
      row['raw_json'] = Substack.safe_json(raw)
      row
    end

    def markdown_quote_lines(flat)
      raw = flat['quote_selections_json'].to_s
      return [] if raw.empty?

      arr = JSON.parse(raw)
      return [] unless arr.is_a?(Array) && !arr.empty?

      lines = ['']
      arr.each_with_index do |q, i|
        lines << '' if i.positive?

        title, url = q.values_at('post_title', 'post_url')
        if title.present? && url.present?
          lines << "> **From:** [#{title}](#{url})"
        elsif title.present?
          lines << "> **From:** #{title}"
        end

        q['text'].to_s.each_line { |line| lines << "> #{line.rstrip}" }
        lines << "> — #{q['attribution']}" if q['attribution'].present?
      end
      lines << ''
    rescue JSON::ParserError
      []
    end

    def render_image_attachment(att)
      url = att['imageUrl'] || att['url']
      url.present? ? ["![](#{url})"] : []
    end

    def render_video_attachment(att)
      mu = att['mediaUpload'] || {}
      name = mu['name'] || 'video'
      playback = mu['mux_playback_id']
      return ["- **Video:** #{name}"] unless playback

      stream = "https://stream.mux.com/#{playback}.m3u8"
      thumb = mu['thumbnail_url'] || mu['poster'] || att['thumbnailUrl'] || att['previewImageUrl']
      lines = []
      lines << "![](#{thumb})" if thumb.present?
      lines << "- **Video:** [#{name}](#{stream})"
      lines
    end

    def render_link_attachment(att)
      meta = att['linkMetadata'] || {}
      url = meta['url'].to_s
      return ["- `link` #{truncated_json(att)}"] unless url.present?

      label = link_attachment_label(meta)
      img = meta['image'] || meta['original_image']
      lines = []
      lines << "![](#{img})" if img.present?
      lines << "[#{label}](#{url})"
      lines
    end

    def link_attachment_label(meta)
      title = meta['title'].to_s.strip
      return title if title.present? && !title.match?(/\A-?\s*YouTube\z/i)
      return meta['host'].to_s if meta['host'].present?

      meta['url'].to_s
    end

    def render_publication_attachment(att)
      pub = att['publication'] || {}
      name = pub['name'].to_s
      url = Substack.homepage(subdomain: pub['subdomain'].to_s, custom_domain: pub['custom_domain'].to_s)
      img = (pub['logo_url'] || pub['logo_url_wide'] || pub['cover_photo_url']).to_s

      lines = []
      lines << "![](#{img})" if img.present?
      if url.present? && name.present?
        lines << "[#{name}](#{url})"
      elsif url.present?
        lines << url
      elsif name.present?
        lines << name
      end
      lines.empty? ? ["- (publication) #{truncated_json(att)}"] : lines
    end

    def render_comment_attachment(att)
      com = att['comment'] || {}
      body = com['body'].to_s
      handle = (com['handle'].presence || com.dig('user', 'handle')).to_s
      cid = com['id'] || com['comment_id']
      key = com['entity_key'].to_s

      url =
        if key.present? && handle.present?
          "https://substack.com/@#{handle}/note/#{key}"
        elsif handle.present? && cid
          "https://substack.com/@#{handle}/note/c-#{cid}"
        end

      lines = []
      lines << "[Quoted comment](#{url})" if url
      excerpt = body.squish.truncate(280)
      lines << "> #{excerpt}" if excerpt.present?
      lines.empty? ? ["- (comment) #{truncated_json(att)}"] : lines
    end

    def render_post_attachment(att)
      return [] if att.dig('postSelection', 'text').to_s.present?

      post = att['post'] || {}
      title = post['title'].to_s
      url = post['canonical_url'].to_s
      if title.present? && url.present?
        ["- **Post:** [#{title}](#{url})"]
      elsif url.present?
        ["- **Post:** #{url}"]
      else
        ["- `post` #{truncated_json(att)}"]
      end
    end

    def markdown_attachments_section(flat)
      raw = flat['attachments_json'].to_s
      return '' if raw.empty?

      arr = JSON.parse(raw)
      return '' unless arr.is_a?(Array) && !arr.empty?

      lines = arr.flat_map do |att|
        type = att['type']
        if ATTACHMENT_TYPES.include?(type)
          send(:"render_#{type}_attachment", att)
        else
          ["- `#{type}` #{truncated_json(att)}"]
        end
      end
      return '' if lines.empty?

      ['', '**Attachments:**', '', *lines, ''].join("\n")
    rescue JSON::ParserError
      ''
    end

    def parent_thread_hint(flat)
      raw = flat['parent_comments_json'].to_s
      return '' if raw.empty?

      arr = JSON.parse(raw)
      return '' unless arr.is_a?(Array) && !arr.empty?

      "\n_(#{arr.size} parent comment(s))_\n"
    rescue JSON::ParserError
      ''
    end

    def markdown_for_note(note)
      flat = BASE_COLUMNS.to_h { |key| [key, note.public_send(key) || ''] }
      heading = [flat['published_at'], flat['entity_key'], 'Note'].map(&:to_s).find(&:present?)

      lines = ["## #{heading}", '']
      lines << "- **Note ID:** `#{flat['entity_key']}`" if flat['entity_key'].present?
      lines << "- **Link:** #{flat['primary_link']}" if flat['primary_link'].present?
      lines << "- **Likes:** #{flat['reaction_count']}" if flat['reaction_count'].present?

      lines.concat(markdown_publication_lines(flat))
      lines.concat(markdown_post_lines(flat))
      lines << "- **Parent comment:** `#{flat['parent_comment_id']}`" if flat['parent_comment_id'].present?

      lines.concat(markdown_quote_lines(flat))
      lines << ''
      lines << flat['body'].to_s
      lines << markdown_attachments_section(flat)
      lines << parent_thread_hint(flat)
      lines << ''
      lines << '* * *'
      lines << ''
      lines.join("\n")
    end

    def markdown_publication_lines(flat)
      pub_name = flat['publication_name'].to_s
      pub_home = Substack.homepage(subdomain: flat['publication_subdomain'].to_s, custom_domain: flat['publication_custom_domain'].to_s)
      lines = []

      if pub_name.present? && pub_home.present?
        lines << "- **Publication:** [#{pub_name}](#{pub_home})"
      elsif pub_name.present?
        lines << "- **Publication:** #{pub_name}"
      elsif pub_home.present?
        lines << "- **Publication URL:** #{pub_home}"
      end
      lines << "![publication](#{flat['publication_logo_url']})" if pub_home.present? && flat['publication_logo_url'].present?
      lines
    end

    def markdown_post_lines(flat)
      post_title = flat['post_title'].to_s
      post_url = flat['post_canonical_url'].to_s
      lines = []

      if post_title.present?
        lines << (post_url.present? ? "- **Post:** [#{post_title}](#{post_url})" : "- **Post:** #{post_title}")
        lines << "- **Post likes:** #{flat['post_reaction_count']}" if flat['post_reaction_count'].present?
      end
      lines << "- **Post subtitle:** #{flat['post_subtitle']}" if flat['post_subtitle'].present?
      lines << "- **Post description:** #{flat['post_description']}" if flat['post_description'].present?
      lines << "![post cover](#{flat['post_cover_image_url']})" if flat['post_cover_image_url'].present?
      lines
    end
  end
end
