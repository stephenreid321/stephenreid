# What the fetches that pass for a browser share
module Http
  # Safari's on a Mac, for the sites that turn away what doesn't look like a browser (Substack's Cloudflare, Goodreads)
  BROWSER_USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.2 Safari/605.1.15'.freeze

  # A browser's headers for a request to url, and these others (those nil left out). Host first, as browsers send it:
  # Ruby's Net::HTTP adds it after the rest unless it's given, and Substack's Cloudflare takes that for a bot, which
  # Substack then rate-limits (429) nearly every request
  def self.browser_headers(url, others = {})
    { 'Host' => URI(url).host, 'User-Agent' => BROWSER_USER_AGENT }.merge(others).compact
  end
end
