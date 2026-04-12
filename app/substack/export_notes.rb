require 'csv'
require 'http'
require 'json'
require 'uri'

# From repo root: foreman run bundle exec ruby app/substack/export_notes.rb

EXPORT_DIR = __dir__
DEFAULT_OUT = File.join(EXPORT_DIR, 'notes.csv')

# Machine delimiter between notes in notes.md; must match SUBSTACK_NOTE_SEPARATOR in helpers.rb
SUBSTACK_NOTE_SEPARATOR = '<!-- substack-note-separator -->'.freeze

USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.2 Safari/605.1.15'

BASE_COLUMNS = %w[
  entity_key feed_item_type context_type context_json published_at primary_link
  post_id post_title post_slug post_canonical_url post_date
  post_restacks post_restacked post_reaction_count post_comment_count
  post_subtitle post_description post_cover_image_url
  publication_id publication_name publication_subdomain publication_custom_domain publication_logo_url
  comment_id comment_author_handle comment_author_name comment_user_id
  comment_photo_url comment_bio parent_comment_id
  body quote_selections_json reaction_count reactions_json restacks restacked children_count
  edited_at media_clip_id attachments_json body_json parent_comments_json
].freeze

# --- Helpers ---

def present?(val)
  !val.to_s.empty?
end

def safe_json(obj)
  return '' if obj.nil?

  JSON.generate(obj)
rescue StandardError
  ''
end

def truncated_json(obj, max = 500)
  s = safe_json(obj)
  s.length > max ? "#{s[0, max]}…" : s
end

def normalize_publication_url(url)
  u = url.to_s.strip
  u.start_with?('http://', 'https://') ? u : "https://#{u}"
end

def substack_homepage(subdomain:, custom_domain:)
  return "https://#{custom_domain}" if present?(custom_domain)
  return "https://#{subdomain}.substack.com" if present?(subdomain)

  ''
end

# --- Field extraction ---

def primary_link(raw)
  post_url = raw.dig('post', 'canonical_url')
  return post_url if post_url

  key = raw['entity_key']
  handle = raw.dig('comment', 'handle')
  return '' unless present?(key) && present?(handle)

  "https://substack.com/@#{handle}/note/#{key}"
end

def post_cover_url(post)
  return '' unless post.is_a?(Hash)

  img = post['cover_image'] || post['coverImage']
  return (img.is_a?(Hash) ? img['url'] || img['URL'] : img).to_s if img

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
    bylines = post['publishedBylines']
    attribution = bylines.is_a?(Array) ? bylines.filter_map { |b| b['name']&.then { |n| n unless n.empty? } }.join(' and ') : ''
    theme = att.dig('postSelectionTheme', 'name').to_s

    { 'text' => text, 'attribution' => attribution, 'post_title' => post['title'].to_s,
      'post_url' => post['canonical_url'].to_s, 'theme' => theme }
  end
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
    'reactions_json' => safe_json(comment['reactions']),
    'restacks' => comment.fetch('restacks', ''),
    'restacked' => comment.key?('restacked') ? comment['restacked'].to_s : '',
    'children_count' => comment.fetch('children_count', ''),
    'edited_at' => comment['edited_at'].to_s,
    'media_clip_id' => comment.fetch('media_clip_id', ''),
    'attachments_json' => safe_json(comment['attachments']),
    'body_json' => safe_json(comment['body_json'])
  }
end

def flatten_raw_note(raw, include_full_json:)
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
    'context_json' => ctx ? safe_json(ctx) : '',
    'published_at' => published_at.to_s,
    'primary_link' => primary_link(raw),
    'post_id' => post ? post['id'] : comment&.dig('post_id'),
    'quote_selections_json' => quote_selections.empty? ? '' : safe_json(quote_selections),
    'parent_comments_json' => raw['parentComments'] ? safe_json(raw['parentComments']) : ''
  }

  row.merge!(post_fields(post))
  row.merge!(publication_fields(pub))
  row.merge!(comment_fields(comment))
  row['raw_json'] = safe_json(raw) if include_full_json
  row
end

# --- Markdown rendering ---

def markdown_quote_lines(flat)
  raw = flat['quote_selections_json'].to_s
  return [] if raw.empty?

  arr = JSON.parse(raw)
  return [] unless arr.is_a?(Array) && !arr.empty?

  result = ['']
  (result + arr.each_with_index.flat_map do |q, i|
    lines = []
    lines << '' if i.positive?

    title, url = q.values_at('post_title', 'post_url')
    if present?(title) && present?(url)
      lines << "> **From:** [#{title}](#{url})"
    elsif present?(title)
      lines << "> **From:** #{title}"
    end

    q['text'].to_s.each_line { |line| lines << "> #{line.rstrip}" }
    lines << "> — #{q['attribution']}" if present?(q['attribution'])
    lines
  end) << ''
rescue JSON::ParserError
  []
end

def render_image_attachment(att)
  url = att['imageUrl'] || att['url']
  present?(url) ? ["![](#{url})"] : []
end

def render_video_attachment(att)
  mu = att['mediaUpload'] || {}
  name = mu['name'] || 'video'
  playback = mu['mux_playback_id']
  return ["- **Video:** #{name}"] unless playback

  stream = "https://stream.mux.com/#{playback}.m3u8"
  # Do not embed https://image.mux.com/.../thumbnail.jpg — Substack uses signed Mux playback,
  # so thumbnails without a JWT return {"error":{"code":7,"message":"Not Authorized"}}.

  thumb = mu['thumbnail_url'] || mu['poster'] || att['thumbnailUrl'] || att['previewImageUrl']
  lines = []
  lines << "![](#{thumb})" if present?(thumb)
  lines << "- **Video:** [#{name}](#{stream})"
  lines
end

def render_link_attachment(att)
  meta = att['linkMetadata'] || {}
  url = meta['url'].to_s
  return ["- `link` #{truncated_json(att)}"] unless present?(url)

  label = link_attachment_label(meta)
  img = meta['image'] || meta['original_image']
  lines = []
  lines << "![](#{img})" if present?(img)
  lines << "[#{label}](#{url})"
  lines
end

def link_attachment_label(meta)
  title = meta['title'].to_s.strip
  return title if present?(title) && !title.match?(/\A-?\s*YouTube\z/i)
  return meta['host'].to_s if present?(meta['host'])

  meta['url'].to_s
end

def render_publication_attachment(att)
  pub = att['publication'] || {}
  name = pub['name'].to_s
  url = substack_homepage(subdomain: pub['subdomain'].to_s, custom_domain: pub['custom_domain'].to_s)
  logo = (pub['logo_url'] || pub['logo_url_wide']).to_s
  cover = pub['cover_photo_url'].to_s
  img = present?(logo) ? logo : cover

  lines = []
  lines << "![](#{img})" if present?(img)
  if present?(url) && present?(name)
    lines << "[#{name}](#{url})"
  elsif present?(url)
    lines << url
  elsif present?(name)
    lines << name
  end
  lines.empty? ? ["- (publication) #{truncated_json(att)}"] : lines
end

def render_comment_attachment(att)
  com = att['comment'] || {}
  body = com['body'].to_s
  handle = com['handle'].to_s
  handle = com.dig('user', 'handle').to_s if handle.empty?
  cid = com['id'] || com['comment_id']
  key = com['entity_key'].to_s

  url =
    if present?(key) && present?(handle)
      "https://substack.com/@#{handle}/note/#{key}"
    elsif present?(handle) && cid
      "https://substack.com/@#{handle}/note/c-#{cid}"
    end

  lines = []
  lines << "[Quoted comment](#{url})" if url
  excerpt = body.gsub(/\s+/, ' ').strip
  excerpt = "#{excerpt[0, 280]}…" if excerpt.length > 280
  lines << "> #{excerpt}" if present?(excerpt)
  lines.empty? ? ["- (comment) #{truncated_json(att)}"] : lines
end

def render_post_attachment(att)
  return [] if att.dig('postSelection', 'text').to_s != ''

  post = att['post'] || {}
  title = post['title'].to_s
  url = post['canonical_url'].to_s
  if present?(title) && present?(url)
    ["- **Post:** [#{title}](#{url})"]
  elsif present?(url)
    ["- **Post:** #{url}"]
  else
    ["- `post` #{truncated_json(att)}"]
  end
end

ATTACHMENT_RENDERERS = {
  'image' => :render_image_attachment,
  'video' => :render_video_attachment,
  'link' => :render_link_attachment,
  'publication' => :render_publication_attachment,
  'comment' => :render_comment_attachment,
  'post' => :render_post_attachment
}.freeze

def markdown_attachments_section(flat)
  raw = flat['attachments_json'].to_s
  return '' if raw.empty?

  arr = JSON.parse(raw)
  return '' unless arr.is_a?(Array) && !arr.empty?

  lines = arr.flat_map do |att|
    renderer = ATTACHMENT_RENDERERS[att['type']]
    renderer ? send(renderer, att) : ["- `#{att['type']}` #{truncated_json(att)}"]
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

def markdown_for_note(flat)
  heading = [flat['published_at'], flat['entity_key'], 'Note'].map(&:to_s).find { |s| !s.empty? }

  lines = ["## #{heading}", '']
  lines << "- **Note ID:** `#{flat['entity_key']}`" if present?(flat['entity_key'])
  lines << "- **Link:** #{flat['primary_link']}" if present?(flat['primary_link'])
  lines << "- **Likes:** #{flat['reaction_count']}" if present?(flat['reaction_count'])

  pub_name = flat['publication_name'].to_s
  pub_home = substack_homepage(subdomain: flat['publication_subdomain'].to_s, custom_domain: flat['publication_custom_domain'].to_s)
  if present?(pub_name) && present?(pub_home)
    lines << "- **Publication:** [#{pub_name}](#{pub_home})"
  elsif present?(pub_name)
    lines << "- **Publication:** #{pub_name}"
  elsif present?(pub_home)
    lines << "- **Publication URL:** #{pub_home}"
  end
  lines << "![publication](#{flat['publication_logo_url']})" if present?(pub_home) && present?(flat['publication_logo_url'])

  post_title = flat['post_title'].to_s
  post_url = flat['post_canonical_url'].to_s
  if present?(post_title)
    lines << (present?(post_url) ? "- **Post:** [#{post_title}](#{post_url})" : "- **Post:** #{post_title}")
  end
  lines << "- **Post likes:** #{flat['post_reaction_count']}" if present?(post_title) && present?(flat['post_reaction_count'])
  lines << "- **Post subtitle:** #{flat['post_subtitle']}" if present?(flat['post_subtitle'])
  lines << "- **Post description:** #{flat['post_description']}" if present?(flat['post_description'])
  lines << "![post cover](#{flat['post_cover_image_url']})" if present?(flat['post_cover_image_url'])
  lines << "- **Parent comment:** `#{flat['parent_comment_id']}`" if present?(flat['parent_comment_id'])

  lines.concat(markdown_quote_lines(flat))
  lines << ''
  lines << flat['body'].to_s
  lines << markdown_attachments_section(flat)
  lines << parent_thread_hint(flat)
  lines << ''
  lines << '* * *'
  lines << SUBSTACK_NOTE_SEPARATOR
  lines << ''
  lines.join("\n")
end

# --- API ---

def fetch_notes_page(http:, base_api:, cursor:)
  path = cursor ? "/notes?cursor=#{URI.encode_www_form_component(cursor)}" : '/notes'
  response = http.get("#{base_api}#{path}")
  raise "HTTP #{response.status}: #{response.body.to_s[0, 200]}" unless response.status.success?

  JSON.parse(response.body.to_s)
end

# --- Main ---

def main
  token = ENV['SUBSTACK_TOKEN']
  publication_url = ENV['SUBSTACK_PUBLICATION_URL']

  if token.to_s.empty? || publication_url.to_s.empty?
    warn 'Set SUBSTACK_TOKEN and SUBSTACK_PUBLICATION_URL in .env and run with foreman run (or export them in the shell).'
    exit 1
  end

  out_path = ENV['SUBSTACK_NOTES_CSV'] || DEFAULT_OUT
  md_path = ENV['SUBSTACK_NOTES_MD'] || File.join(File.dirname(out_path), "#{File.basename(out_path, '.csv')}.md")
  include_full_json = %w[1 true].include?(ENV['SUBSTACK_NOTES_FULL_JSON']&.downcase)

  base_api = "#{normalize_publication_url(publication_url).chomp('/')}/api/v1"
  http = HTTP.headers(
    'Cookie' => "substack.sid=#{token}",
    'Accept' => 'application/json',
    'Content-Type' => 'application/json',
    'User-Agent' => USER_AGENT
  )

  columns = include_full_json ? [*BASE_COLUMNS, 'raw_json'] : BASE_COLUMNS.dup
  count = 0
  cursor = nil

  CSV.open(out_path, 'w', encoding: 'UTF-8') do |csv|
    File.open(md_path, 'w:UTF-8') do |md|
      csv << columns

      loop do
        data = fetch_notes_page(http: http, base_api: base_api, cursor: cursor)
        (data['items'] || []).each do |raw|
          flat = flatten_raw_note(raw, include_full_json: include_full_json)
          csv << columns.map { |k| flat[k] }
          md.write(markdown_for_note(flat))
          count += 1
        end

        cursor = data['nextCursor']
        break if cursor.to_s.empty?
      end
    end
  end

  puts "✅ Wrote #{count} notes to #{out_path} and #{md_path}"
  puts '💡 Tip: SUBSTACK_NOTES_FULL_JSON=1 adds a raw_json column with the full API payload per row.' unless include_full_json
end

main
