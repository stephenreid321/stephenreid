# Readwise Reader's API, as the account whose token is READWISE_ACCESS_TOKEN
module Readwise
  # Query parameters that only track who shared a link or how it was clicked
  TRACKING_PARAMS = /\A(utm_.*|fbclid|gclid|mc_cid|mc_eid|_bhlid|triedRedirect)\z/

  # The documents archived since a time, oldest first, with source_url, title, author, summary, image_url and
  # last_moved_at. Each source_url is clean_url's
  def self.archived_since(time, token: ENV.fetch('READWISE_ACCESS_TOKEN'))
    response = Faraday.get('https://readwise.io/api/v3/list', { location: 'archive', updatedAfter: time.iso8601 },
                           { 'Authorization' => "Token #{token}" })
    raise "Readwise: #{response.status}" unless response.success?

    JSON.parse(response.body)['results']
        .select { |r| Time.parse(r['last_moved_at']) >= time }
        .sort_by { |r| Time.parse(r['last_moved_at']) }
        .each { |r| r['source_url'] = clean_url(r['source_url']) }
  end

  # Of the last 50 links archived in the last week, oldest first, so the newest is posted last and sits on top, those
  # not among posted_urls (as clean_url cleans them, as those posted before it cleaned them still have their trackers),
  # each once. With after_newest, only those archived after the newest of them that has been posted
  def self.to_post(posted_urls, after_newest: false)
    posted = posted_urls.map { |url| clean_url(url) }
    archived = archived_since(7.days.ago).last(50)
    newest = archived.rindex { |r| posted.include?(r['source_url']) } if after_newest
    archived.drop(newest ? newest + 1 : 0).reject { |r| posted.include?(r['source_url']) }.uniq { |r| r['source_url'] }
  end

  # A link as it's posted: without its tracking parameters, and YouTube's short links made long. Compare links already
  # posted through it too, as those posted before it cleaned them still have theirs
  def self.clean_url(url)
    url = url.gsub('youtu.be/', 'youtube.com/watch?v=')
    uri = URI.parse(url)
    return url unless uri.query

    params = URI.decode_www_form(uri.query).reject do |name, _|
      # Substack's referrer, r, on its posts (/p/…) and notes (substack.com/@…)
      name.match?(TRACKING_PARAMS) || (name == 'r' && (uri.path.start_with?('/p/') || uri.host.to_s.end_with?('substack.com')))
    end
    uri.query = params.empty? ? nil : URI.encode_www_form(params)
    uri.to_s
  rescue URI::InvalidURIError
    url
  end
end
