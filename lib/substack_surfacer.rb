# The posts of the last 90 days from every newsletter Stephen subscribes to on Substack, with their likes and the
# newsletter's free subscribers, so /substack can sort them by likes per subscriber. A port of
# https://github.com/stephenreid321/substack_surfacer, into data/fetched/substack_surfacer.json (rake data:substack_surfacer).
# Substack's Cloudflare turns away GitHub's runners, so substack-surfacer.yml runs it on Stephen's Mac
module SubstackSurfacer
  PROFILE = 'stephenreid'.freeze
  # Newsletters the page leaves out, by their homepage as in the data. They're still fetched, so the data has them
  SKIPPED = %w[
    https://on.substack.com
  ].freeze
  DAYS = 90
  # Newsletters fetched at once: 24 was no faster, 48 hit Substack's rate limits
  WORKERS = 12
  # Substack's archive API refuses a limit over 25
  PAGE_SIZE = 25
  TIMEOUT = 10
  # Tries for a rate-limited request, and for a timeout, connection error or 5xx
  RATE_LIMIT_TRIES = 8
  TRANSIENT_TRIES = 3
  MAX_WAIT = 60

  class Error < StandardError; end

  class << self
    def fetch
      # DAYS days of 24 hours back from now, which is what the page counts back from (fetched_at) and how it counts. Not
      # DAYS.days.ago, which counts days on the clock, and so an hour more or less across a change to or from summer time
      fetched_at = Time.now.utc.floor
      since = fetched_at - (DAYS * 24 * 60 * 60)
      newsletters = subscriptions
      raise Error, "No subscriptions on Substack's profile of @#{PROFILE}" if newsletters.empty?

      puts "Substack Surfacer: #{newsletters.size} newsletters, posts since #{since.to_date}"
      failed = []
      posts = in_parallel(newsletters) do |url|
        newsletter_posts(url, since)
      rescue StandardError => e
        failed << url
        puts "⚠️  #{url}: #{e.message.truncate(200)}"
        []
      end.flatten

      # Most failing means something's wrong (Cloudflare, say): keep the posts fetched last time rather than a page of few
      raise Error, "#{failed.size} of #{newsletters.size} newsletters failed" if failed.size > newsletters.size / 2

      Fetched.write(:substack_surfacer, { 'fetched_at' => fetched_at.iso8601, 'days' => DAYS, 'posts' => posts.sort_by { |p| p['post_date'] }.reverse })
      puts "Substack Surfacer: #{posts.size} posts from #{posts.uniq { |p| p['newsletter_url'] }.size} newsletters (#{failed.size} failed)"
    end

    # The homepage of each newsletter the profile subscribes to or helps run, from the JSON its page preloads. Substack
    # leaves those it helps run (publicationUsers: Metamoderna, say) out of its subscriptions
    def subscriptions
      # As it is now: Substack's Cloudflare caches the profile page for some minutes, so a newsletter just unsubscribed from
      # would still be there. A query string it hasn't seen gets one from Substack itself
      html = get("https://substack.com/@#{PROFILE}?#{URI.encode_www_form(fresh: Time.now.to_i)}").body.to_s
      json = Nokogiri::HTML(html).at('script#preloads-json')&.text
      raise Error, "Substack's profile page has no preloads-json" if json.blank?

      data = JSON.parse(json)
      data = JSON.parse(data) if data.is_a?(String)
      (Array(data.dig('profile', 'subscriptions')) + Array(data.dig('profile', 'publicationUsers'))).filter_map do |entry|
        publication = entry['publication'] || {}
        Substack.homepage(subdomain: publication['subdomain'], custom_domain: publication['custom_domain']).presence
      end.uniq
    end

    # The newsletter's posts since +since+, newest first
    def newsletter_posts(url, since)
      subscribers, hidden_sections = homepage(url)
      # The archive leaves out the posts of a section that hides them from the newsletter's listings, so those come from
      # each such section's archive
      found = archive(url, since) + hidden_sections.flat_map { |section_id| archive(url, since, section_id: section_id) }
      posts = found.uniq { |post| post['id'] }.sort_by { |post| post['post_date'].to_s }.reverse.filter_map do |post|
        date = parse_time(post['post_date'])
        next unless date && date >= since

        post_attributes(url, post, date)
      end
      count = subscriber_number(subscribers)
      posts.each do |post|
        post['free_subscribers'] = subscribers
        post['likes_per_100_free_subscribers'] = (100.0 * post['likes'] / count).round(6) if count&.positive? && post['likes']
      end
    end

    # For the page's template: when they were fetched, and the posts with what the table sorts by, in the order the table
    # first sorts them (by likes per 100 free subscribers, highest first, then newest first), so they don't jump about when
    # it does
    def for_template
      data = Fetched.read(:substack_surfacer, {})
      # How many posts each newsletter has in the data: those of the last DAYS days
      newsletter_posts = Array(data['posts']).map { |post| post['newsletter_url'] }.tally
      posts = Array(data['posts']).reject { |post| SKIPPED.include?(post['newsletter_url']) }.map do |post|
        post.merge('newsletter_posts' => newsletter_posts[post['newsletter_url']],
                   'free_subscribers_sort' => subscriber_number(post['free_subscribers']) || -1,
                   'likes_per_100_free_subscribers_sort' => post['likes_per_100_free_subscribers'] || -1,
                   'likes_per_100_free_subscribers_shown' => significant_figures(post['likes_per_100_free_subscribers']),
                   'free_subscribers_shown' => post['free_subscribers']&.delete_suffix('+'),
                   'post_day' => Time.zone.parse(post['post_date']).strftime('%-d %b'))
      end.sort_by { |post| [-post['likes_per_100_free_subscribers_sort'], -Time.parse(post['post_date']).to_i] }
      { 'fetched_at' => data['fetched_at'], 'days' => data['days'] || DAYS, 'posts' => posts }
    end

    # The number to three significant figures (225, 71.9, 0.417), or nil
    def significant_figures(number, figures = 3)
      return if number.nil?
      return '0' if number.zero?

      decimals = figures - 1 - Math.log10(number.abs).floor
      # Again if rounding made it a power of 10 more (9.996 to 10.0)
      decimals = figures - 1 - Math.log10(number.round(decimals).abs).floor
      decimals.positive? ? format("%.#{decimals}f", number.round(decimals)) : number.round(decimals).round.to_s
    end

    # "1,234", "3K+" or "1M+" as a number, the bottom of the band; nil if it isn't one
    def subscriber_number(text)
      text = text.to_s.delete(',').delete_suffix('+').strip
      multiplier = { 'K' => 1_000, 'M' => 1_000_000 }[text[-1].to_s.upcase]
      text = text[0..-2] if multiplier
      Float(text) * (multiplier || 1)
    rescue ArgumentError
      nil
    end

    private

    # Newest first, page by page, until a page reaches back before +since+
    # (Or the section's)
    def archive(url, since, section_id: nil)
      posts = []
      cursor = nil
      loop do
        query = { sort: 'new', limit: PAGE_SIZE, section_id: section_id, cursor: cursor }.compact
        json = JSON.parse(get("#{url}/api/v1/archive?#{URI.encode_www_form(query)}").body.to_s)
        page = Array(json['posts'])
        posts.concat(page)
        cursor = json['nextCursor'].presence
        break if page.empty? || cursor.nil?

        oldest = parse_time(page.last['post_date'])
        break if oldest && oldest < since
      end
      posts
    end

    def parse_time(value)
      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def post_attributes(url, post, date)
      authors = Array(post['publishedBylines']).filter_map { |byline| byline['name'].presence }
      {
        'newsletter_name' => newsletter_name(url),
        'newsletter_url' => url,
        'post_id' => post['id'],
        'post_url' => post['canonical_url'].to_s,
        'title' => post['title'].to_s,
        'subtitle' => post['subtitle'].to_s,
        'author' => authors.join(', ').presence || newsletter_name(url),
        'post_date' => date.utc.iso8601,
        'likes' => post['reaction_count'],
        'word_count' => post['wordcount'],
        # For paid subscribers (only_paid) or founding members (founding). Not only_subscribers, which any free subscriber reads
        'paid' => %w[only_paid founding].include?(post['audience'])
      }
    end

    # The subdomain of a substack.com newsletter, or a custom domain
    def newsletter_name(url)
      host = URI(url).host.to_s
      host.end_with?('.substack.com') ? host.delete_suffix('.substack.com') : host
    end

    # From the JSON the newsletter's homepage carries: its free subscribers as Substack shows them ("4.8K+", or nil if it
    # doesn't say), and the ids of its sections that hide their posts from its listings. Nil and none if it won't load
    def homepage(url)
      html = get(url).body.to_s
      subscribers = %w[freeSubscriberCount freeSubscriberCountOrderOfMagnitude].lazy.filter_map do |key|
        html.match(/\\?"#{key}\\?":\\?"([^"\\]+)/)&.[](1)
      end.first
      [subscribers, hidden_sections(html)]
    rescue StandardError => e
      puts "⚠️  #{url}: no homepage (#{e.message.truncate(100)})"
      [nil, []]
    end

    def hidden_sections(html)
      json = Nokogiri::HTML(html).at('script#preloads-json')&.text
      return [] if json.blank?

      data = JSON.parse(json)
      data = JSON.parse(data) if data.is_a?(String)
      Array(data.dig('pub', 'sections')).select { |section| section['hide_posts_from_pub_listings'] }.filter_map { |section| section['id'] }
    rescue JSON::ParserError
      []
    end

    # Each item handed to the block on WORKERS threads, and what the blocks return, in the items' order
    def in_parallel(items, &block)
      queue = Queue.new
      items.each_with_index { |item, i| queue << [item, i] }
      queue.close
      results = Array.new(items.size)
      Array.new([WORKERS, items.size].min) do
        Thread.new do
          while (pair = queue.pop)
            results[pair.last] = block.call(pair.first)
          end
        end
      end.each(&:join)
      results
    end

    # A GET, following redirects, retrying when rate-limited (as Retry-After says, or backing off) and on timeouts,
    # connection errors and 5xx
    def get(url, redirects: 5)
      rate_limited = 0
      transient = 0
      loop do
        response = client.get(url, nil, headers(url))
        if response.status.between?(300, 399) && response.headers['location'] && redirects.positive?
          return get(URI.join(url, response.headers['location']).to_s, redirects: redirects - 1)
        elsif response.status == 429 && (rate_limited += 1) < RATE_LIMIT_TRIES
          retry_after = response.headers['retry-after'].to_s
          sleep [retry_after.match?(/\A\d+\z/) ? retry_after.to_i : 2**rate_limited, MAX_WAIT].min
        elsif response.status >= 500 && (transient += 1) < TRANSIENT_TRIES
          sleep 2**transient
        elsif response.success?
          return response
        else
          raise Error, "HTTP #{response.status} from #{url}"
        end
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        raise Error, "#{e.class.name.demodulize} from #{url}" unless (transient += 1) < TRANSIENT_TRIES

        sleep 2**transient
      end
    end

    # One for each thread. Without Faraday's own User-Agent, so each request's headers come in the order headers gives
    def client
      Thread.current[:substack_surfacer_client] ||= Faraday.new(request: { timeout: TIMEOUT }).tap { |conn| conn.headers.clear }
    end

    # Host first, as browsers send it. Ruby's Net::HTTP adds it after the rest unless it's given, and Substack's
    # Cloudflare takes that for a bot: Substack then rate-limits nearly every request, and a fetch of seconds takes minutes
    def headers(url)
      { 'Host' => URI(url).host, 'User-Agent' => Substack::USER_AGENT }
    end
  end
end
