# What fetching from Substack shares: the publication's API (SUBSTACK_PUBLICATION_URL, signed in with SUBSTACK_TOKEN)
# for its notes and posts, and any newsletter's archive and pages, for SubstackSurfacer
module Substack
  CDN_IMAGE_HOST = 'substackcdn.com'.freeze
  GALLERY_IMAGE_WIDTH = 480
  # Substack's archive API refuses a limit over 25
  ARCHIVE_PAGE_SIZE = 25

  # A 429, tried again up to 7 more times, after as long as its Retry-After says (or 2, 4, 8... seconds), up to a minute
  RATE_LIMIT_RETRY = {
    max: 7, interval: 2, backoff_factor: 2, max_interval: 60,
    retry_statuses: [429], exceptions: [Faraday::RetriableResponse],
    header_parser_block: ->(retry_after) { retry_after.to_i.clamp(0, 60) if retry_after.to_s.match?(/\A\d+\z/) }
  }.freeze
  # A timeout, a dropped connection or an error on Substack's side, tried again twice more, after 2 then 4 seconds
  TRANSIENT_RETRY = {
    max: 2, interval: 2, backoff_factor: 2,
    retry_statuses: [500, 502, 503, 504], exceptions: [Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::RetriableResponse]
  }.freeze

  class << self
    # A connection that retries as RATE_LIMIT_RETRY and TRANSIENT_RETRY say. Without Faraday's own User-Agent, so each
    # request's headers come in the order Http.browser_headers gives
    def connection(timeout: nil)
      Faraday.new(request: { timeout: timeout }.compact) do |f|
        f.request :retry, RATE_LIMIT_RETRY
        f.request :retry, TRANSIENT_RETRY
      end.tap { |conn| conn.headers.clear }
    end

    def api_sync_enabled?
      ENV['SUBSTACK_TOKEN'].present? && ENV['SUBSTACK_PUBLICATION_URL'].present?
    end

    def publication_url
      url = ENV['SUBSTACK_PUBLICATION_URL'].to_s.strip.chomp('/')
      url.start_with?('http://', 'https://') ? url : "https://#{url}"
    end

    # A path of the publication's API (/notes, say), or a URL of it, signed in, as JSON
    def publication_json(path)
      url = path.start_with?('https://', 'http://') ? path : "#{publication_url}/api/v1#{path}"
      headers = Http.browser_headers(url, 'Accept' => 'application/json', 'Content-Type' => 'application/json',
                                          'Cookie' => "substack.sid=#{ENV['SUBSTACK_TOKEN']}")
      response = (@publication_connection ||= connection).get(url, nil, headers)
      raise "HTTP #{response.status}: #{response.body.to_s.byteslice(0, 200)}" unless response.success?

      JSON.parse(response.body.to_s)
    end

    # A post of the publication with its body, trying again while Substack sends it without one (it sometimes does) or
    # fails, max_attempts times in all. The last it sent if none has a body, or nil
    def publication_post(slug, max_attempts: 5)
      return if slug.blank?

      detail = nil
      error = nil
      max_attempts.times do |attempt|
        sleep(0.5 * attempt) if attempt.positive?
        detail = publication_json("/posts/#{ERB::Util.url_encode(slug)}")
        return detail if detail['body_html'].present?

        error = 'body_html blank'
      rescue RuntimeError, JSON::ParserError => e
        error = e.message
      end
      puts "⚠️  Substack post detail: failed after #{max_attempts} attempt(s) (slug=#{slug}, error=#{error})"
      detail
    end

    # The newsletter's posts, newest first, a page at a time with Substack's cursor, until a page reaches back before
    # since (all of them, without since). Or those of one of its sections. The block GETs a URL as JSON
    def archive(homepage, since: nil, section_id: nil)
      posts = []
      cursor = nil
      loop do
        query = { sort: 'new', limit: ARCHIVE_PAGE_SIZE, section_id: section_id, cursor: cursor }.compact
        json = yield("#{homepage}/api/v1/archive?#{URI.encode_www_form(query)}")
        page = Array(json['posts'])
        posts.concat(page)
        cursor = json['nextCursor'].presence
        break if page.empty? || cursor.nil?
        break if since && (oldest = parse_time(page.last['post_date'])) && oldest < since
      end
      posts
    end

    # The JSON a Substack page preloads (script#preloads-json, sometimes JSON in a JSON string), or nil if it has none
    def preloads(html)
      json = Nokogiri::HTML(html).at('script#preloads-json')&.text
      return if json.blank?

      data = JSON.parse(json)
      data.is_a?(String) ? JSON.parse(data) : data
    end

    def parse_time(value)
      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    # Resize via Substack CDN (WebP, width-limited). Unwraps existing CDN URLs first.
    def gallery_image_url(url, width: GALLERY_IMAGE_WIDTH)
      source = unwrap_cdn_image_url(url.to_s.strip)
      return source unless source.start_with?('http://', 'https://')

      "https://#{CDN_IMAGE_HOST}/image/fetch/w_#{width.to_i},c_limit,f_webp,q_auto:good/#{URI.encode_www_form_component(source)}"
    end

    def unwrap_cdn_image_url(url)
      return url unless url.include?("#{CDN_IMAGE_HOST}/image/fetch") && url =~ /(https%3A%2F%2F.+)\z/

      URI.decode_www_form_component(Regexp.last_match(1))
    end

    # Just +fields+ of the hash +obj+: each a key, or { key => fields } for those of a hash under it. Substack's JSON
    # changes from one fetch to the next in ways the site doesn't show (counts, prices, tracking), so data/fetched keeps
    # only what the site reads, and changes only when that does
    def pick(obj, fields)
      return unless obj.is_a?(Hash)

      fields.each_with_object({}) do |field, picked|
        if field.is_a?(Hash)
          field.each { |key, nested| (value = pick(obj[key], nested)) && (picked[key] = value) }
        elsif obj.key?(field)
          picked[field] = obj[field]
        end
      end
    end

    def homepage(subdomain:, custom_domain:)
      return "https://#{custom_domain}" if custom_domain.present?
      return "https://#{subdomain}.substack.com" if subdomain.present?

      ''
    end

    # Substack @-mentions are empty <span class="mention-wrap"> nodes; the label lives in data-attrs JSON and is filled
    # in by client JS. Expand them so markdown conversion keeps the names.
    def expand_mentions!(doc)
      doc.css('span.mention-wrap, [data-component-name="MentionToDOM"]').each do |node|
        attrs = begin
          JSON.parse(node['data-attrs'].to_s)
        rescue JSON::ParserError
          {}
        end
        name = attrs['name'].to_s.strip
        next if name.blank?

        url = mention_url(attrs)
        node.replace(url.present? ? node.document.create_element('a', name, 'href' => url) : name)
      end
      doc
    end

    def mention_url(attrs)
      return attrs['url'].to_s.strip if attrs['url'].present?
      return '' if attrs['id'].blank?

      slug = attrs['name'].to_s.parameterize
      "https://open.substack.com/users/#{slug.present? ? "#{attrs['id']}-#{slug}" : attrs['id']}"
    end
  end
end
