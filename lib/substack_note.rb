# A Substack note, from data/fetched/substack_notes.json (rake data:substack)
class SubstackNote
  # What's kept of each note: only what the site reads, as everything else Substack sends changes from one fetch to the
  # next (counts, prices, uploads) and would have `substack.yml` save them and rebuild the site for nothing.
  # attachments are each of the note's attachments, with only the fields its render_<type>_attachment reads
  # (ATTACHMENT_FIELDS), and quote_selections each passage of a post it quotes
  FIELDS = %w[
    entity_key body published_at primary_link reaction_count parent_comment_id parent_comment_count
    post_title post_canonical_url post_subtitle post_description post_cover_image_url post_reaction_count
    publication_name publication_subdomain publication_custom_domain publication_logo_url
    comment_author_handle attachments quote_selections
  ].freeze

  attr_reader(*FIELDS)

  PUBLICATION_FIELDS = %w[name subdomain custom_domain logo_url logo_url_wide cover_photo_url].freeze
  ATTACHMENT_FIELDS = {
    'image' => %w[imageUrl url],
    'video' => ['thumbnailUrl', 'previewImageUrl', { 'mediaUpload' => %w[name mux_playback_id thumbnail_url poster] }],
    'link' => [{ 'linkMetadata' => %w[url title host image original_image] }],
    'publication' => [{ 'publication' => PUBLICATION_FIELDS }],
    'publication_recommendation' => [{ 'publicationRecommendation' => [{ 'recommendedPublication' => PUBLICATION_FIELDS }] }],
    'comment' => [{ 'comment' => ['body', 'handle', 'id', 'comment_id', 'entity_key', { 'user' => %w[handle] }] }],
    'post' => [{ 'postSelection' => %w[text] }, { 'post' => %w[title canonical_url] }]
  }.freeze

  def initialize(attributes)
    attributes = attributes.transform_keys(&:to_s)
    # As notes were kept until substack.yml next fetches them: attachments and quote_selections as JSON in a string
    %w[attachments quote_selections].each do |name|
      attributes[name] ||= JSON.parse(attributes["#{name}_json"]) if attributes["#{name}_json"].present?
    end
    FIELDS.each { |name| instance_variable_set(:"@#{name}", attributes[name]) }
    @attachments = Array(@attachments)
    @quote_selections = Array(@quote_selections)
  end

  # Its public URL on Substack, for the homepage's gallery
  def gallery_note_url
    return primary_link if primary_link.present?

    "https://substack.com/@#{comment_author_handle}/note/#{entity_key}" if comment_author_handle.present? && entity_key.present?
  end

  # Its images, then the cover of the post it's about, each once
  def image_urls_for_gallery
    urls = attachments.filter_map { |att| (att['imageUrl'] || att['url']).to_s.strip.presence if att['type'] == 'image' }
    (urls + [post_cover_image_url.to_s.strip.presence].compact).uniq
  end

  def to_markdown
    lines = ["## #{[published_at, entity_key, 'Note'].find(&:present?)}", '']
    lines << "- **Note ID:** `#{entity_key}`" if entity_key.present?
    lines << "- **Link:** #{primary_link}" if primary_link.present?
    lines << "- **Likes:** #{reaction_count}" unless reaction_count.nil?
    lines.concat(publication_lines, post_lines)
    lines << "- **Parent comment:** `#{parent_comment_id}`" if parent_comment_id.present?
    lines.concat(quote_lines)
    lines.push('', body.to_s, attachments_section)
    lines << (parent_comment_count.to_i.positive? ? "\n_(#{parent_comment_count} parent comment(s))_\n" : '')
    lines.push('', '* * *', '')
    lines.join("\n")
  end

  class << self
    # Newest first
    def all
      Fetched.read(:substack_notes).map { |attributes| new(attributes) }.sort_by { |note| note.published_at.to_s }.reverse
    end

    # Substack API → data/fetched/substack_notes.json. Env: SUBSTACK_TOKEN, SUBSTACK_PUBLICATION_URL.
    def import
      unless Substack.api_sync_enabled?
        puts 'ℹ️  API import skipped: set SUBSTACK_TOKEN and SUBSTACK_PUBLICATION_URL.'
        return
      end

      raw_notes = []
      cursor = nil
      loop do
        data = Substack.publication_json(cursor ? "/notes?cursor=#{URI.encode_www_form_component(cursor)}" : '/notes')
        raw_notes.concat(data['items'] || [])
        break if (cursor = data['nextCursor']).blank?
      end

      notes = raw_notes.reverse.filter_map { |raw| attributes_of(raw) }.uniq { |note| note['entity_key'] }
      Fetched.write(:substack_notes, notes)

      puts "🗄️  API import: #{notes.size} SubstackNote(s)"
    end

    def markdown_export(limit: nil)
      notes = all
      notes = notes.first(limit.to_i) if limit.to_i.positive?
      notes.map(&:to_markdown).join
    end

    # Newest notes first; flattens images (+ post covers) into up to +limit+ cells.
    def recent_gallery_items(limit: 20)
      all.each_with_object([]) do |note, items|
        next if (url = note.gallery_note_url).blank?

        note.image_urls_for_gallery.each do |img|
          items << { image_url: Substack.gallery_image_url(img), note_url: url, published_at: note.published_at.to_s }
          return items if items.size >= limit
        end
      end
    end

    private

    # What's kept of a note as Substack's API sends it (FIELDS), or nil if it has no entity_key
    def attributes_of(raw)
      return if raw['entity_key'].to_s.strip.empty?

      comment = raw['comment'] || {}
      post = raw['post'] || {}
      publication = raw['publication'] || {}
      {
        'entity_key' => raw['entity_key'].to_s.strip,
        'body' => comment['body'],
        'published_at' => raw.dig('context', 'timestamp') || comment['date'] || post['post_date'],
        'primary_link' => post['canonical_url'] || (note_url(comment['handle'], raw['entity_key']) if comment['handle'].present?),
        'reaction_count' => comment['reaction_count'],
        'parent_comment_id' => comment['parent_comment_id'] || comment['parent_id'] || comment.dig('parent_comment', 'id'),
        'parent_comment_count' => (raw['parentComments'].size if raw['parentComments'].is_a?(Array)),
        'post_title' => post['title'],
        'post_canonical_url' => post['canonical_url'],
        'post_subtitle' => post['subtitle'],
        'post_description' => post['description'],
        'post_cover_image_url' => cover_url(post),
        'post_reaction_count' => post['reaction_count'],
        'publication_name' => publication['name'],
        'publication_subdomain' => publication['subdomain'],
        'publication_custom_domain' => publication['custom_domain'],
        'publication_logo_url' => publication['logo_url'] || publication['logoUrl'],
        'comment_author_handle' => comment['handle'],
        'attachments' => Array(comment['attachments']).filter_map { |att| Substack.pick(att, ['type', *ATTACHMENT_FIELDS[att['type']]]) },
        'quote_selections' => quote_selections(comment['attachments'])
      }.compact_blank
    end

    def note_url(handle, key)
      "https://substack.com/@#{handle}/note/#{key}"
    end

    def cover_url(post)
      cover = post['cover_image'] || post['coverImage']
      cover = cover['url'] || cover['URL'] if cover.is_a?(Hash)
      (cover || post['cover_image_url'] || post['coverImageUrl']).presence
    end

    # The passages of posts the note quotes, each with what it's from
    def quote_selections(attachments)
      Array(attachments).filter_map do |att|
        next unless att['type'] == 'post' && (text = att.dig('postSelection', 'text').to_s).present?

        post = att['post'] || {}
        { 'text' => text, 'attribution' => Array(post['publishedBylines']).filter_map { |b| b['name'].presence }.join(' and '),
          'post_title' => post['title'].to_s, 'post_url' => post['canonical_url'].to_s, 'theme' => att.dig('postSelectionTheme', 'name').to_s }
      end
    end
  end

  private

  def publication_lines
    home = Substack.homepage(subdomain: publication_subdomain, custom_domain: publication_custom_domain)
    lines = []
    if publication_name.present?
      lines << "- **Publication:** #{home.present? ? "[#{publication_name}](#{home})" : publication_name}"
    elsif home.present?
      lines << "- **Publication URL:** #{home}"
    end
    lines << "![publication](#{publication_logo_url})" if home.present? && publication_logo_url.present?
    lines
  end

  def post_lines
    lines = []
    if post_title.present?
      lines << "- **Post:** #{post_canonical_url.present? ? "[#{post_title}](#{post_canonical_url})" : post_title}"
      lines << "- **Post likes:** #{post_reaction_count}" unless post_reaction_count.nil?
    end
    lines << "- **Post subtitle:** #{post_subtitle}" if post_subtitle.present?
    lines << "- **Post description:** #{post_description}" if post_description.present?
    lines << "![post cover](#{post_cover_image_url})" if post_cover_image_url.present?
    lines
  end

  def quote_lines
    return [] if quote_selections.empty?

    lines = ['']
    quote_selections.each_with_index do |q, i|
      lines << '' if i.positive?
      title, url = q.values_at('post_title', 'post_url')
      lines << "> **From:** #{url.present? ? "[#{title}](#{url})" : title}" if title.present?
      q['text'].to_s.each_line { |line| lines << "> #{line.rstrip}" }
      lines << "> — #{q['attribution']}" if q['attribution'].present?
    end
    lines << ''
  end

  def attachments_section
    lines = attachments.flat_map do |att|
      ATTACHMENT_FIELDS.key?(att['type']) ? send(:"render_#{att['type']}_attachment", att) : ["- `#{att['type']}`"]
    end
    lines.empty? ? '' : ['', '**Attachments:**', '', *lines, ''].join("\n")
  end

  def render_image_attachment(att)
    url = att['imageUrl'] || att['url']
    url.present? ? ["![](#{url})"] : []
  end

  def render_video_attachment(att)
    upload = att['mediaUpload'] || {}
    name = upload['name'] || 'video'
    return ["- **Video:** #{name}"] unless upload['mux_playback_id']

    thumb = upload['thumbnail_url'] || upload['poster'] || att['thumbnailUrl'] || att['previewImageUrl']
    [("![](#{thumb})" if thumb.present?), "- **Video:** [#{name}](https://stream.mux.com/#{upload['mux_playback_id']}.m3u8)"].compact
  end

  def render_link_attachment(att)
    meta = att['linkMetadata'] || {}
    return ["- `link` #{truncated_json(att)}"] if meta['url'].blank?

    title = meta['title'].to_s.strip
    label = title.present? && !title.match?(/\A-?\s*YouTube\z/i) ? title : meta['host'].presence || meta['url']
    image = meta['image'] || meta['original_image']
    [("![](#{image})" if image.present?), "[#{label}](#{meta['url']})"].compact
  end

  def render_publication_attachment(att)
    publication = att['publication'] || {}
    name = publication['name'].to_s
    url = Substack.homepage(subdomain: publication['subdomain'], custom_domain: publication['custom_domain'])
    image = (publication['logo_url'] || publication['logo_url_wide'] || publication['cover_photo_url']).to_s
    lines = [("![](#{image})" if image.present?), (url.present? && name.present? ? "[#{name}](#{url})" : url.presence || name.presence)].compact
    lines.empty? ? ["- (publication) #{truncated_json(att)}"] : lines
  end

  def render_publication_recommendation_attachment(att)
    render_publication_attachment('publication' => att.dig('publicationRecommendation', 'recommendedPublication'))
  end

  def render_comment_attachment(att)
    comment = att['comment'] || {}
    handle = (comment['handle'].presence || comment.dig('user', 'handle')).to_s
    id = comment['id'] || comment['comment_id']
    url = if comment['entity_key'].present? && handle.present?
            "https://substack.com/@#{handle}/note/#{comment['entity_key']}"
          elsif handle.present? && id
            "https://substack.com/@#{handle}/note/c-#{id}"
          end
    excerpt = comment['body'].to_s.squish.truncate(280)
    lines = [("[Quoted comment](#{url})" if url), ("> #{excerpt}" if excerpt.present?)].compact
    lines.empty? ? ["- (comment) #{truncated_json(att)}"] : lines
  end

  def render_post_attachment(att)
    return [] if att.dig('postSelection', 'text').present?

    title, url = (att['post'] || {}).values_at('title', 'canonical_url').map(&:to_s)
    if url.blank?
      ["- `post` #{truncated_json(att)}"]
    else
      ["- **Post:** #{title.present? ? "[#{title}](#{url})" : url}"]
    end
  end

  def truncated_json(obj, max = 500)
    json = JSON.generate(obj)
    json.length > max ? "#{json[0, max]}…" : json
  end
end
