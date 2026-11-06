# Stephen's library export from Goodreads, into data/goodreads_library_export.csv. Goodreads has no API for it any more,
# so this does what its Export Library button does (https://www.goodreads.com/review/import), signed in with the Cookie
# header of a signed-in browser (GOODREADS_COOKIE): asks for a new export, waits for it, and downloads it
module Goodreads
  BASE_URL = 'https://www.goodreads.com'.freeze
  USER_ID = '55629816'.freeze
  EXPORT_PATH = "#{ROOT}/data/goodreads_library_export.csv".freeze
  USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.2 Safari/605.1.15'.freeze
  # How long to wait for Goodreads to make the export, and how often to look
  WAIT = 5.minutes
  POLL = 5.seconds

  class << self
    def fetch
      csv = export
      File.write(EXPORT_PATH, csv)
      puts "Goodreads: #{CSV.parse(csv, headers: true).count} books"
    end

    private

    def export
      http = client
      http.headers['X-CSRF-Token'] = csrf_token(http)
      response = http.post("/review_porter/export/#{USER_ID}")
      raise "Goodreads didn't start the export: #{response.status}" unless response.success?

      # Goodreads drops the last export once asked for a new one, so the file is there again when the new one's ready
      deadline = WAIT.from_now
      until http.head(csv_path).success?
        raise "Goodreads' export wasn't ready after #{WAIT.inspect}" if Time.now > deadline

        sleep POLL
      end

      response = http.get(csv_path)
      raise "Goodreads' export didn't download: #{response.status}" unless response.success?

      csv = response.body.force_encoding('UTF-8')
      raise "Goodreads' export isn't the library CSV: #{csv[0, 100].inspect}" unless csv.start_with?('Book Id,Title,Author')

      csv
    end

    def csv_path
      "/review_porter/export/#{USER_ID}/goodreads_export.csv"
    end

    # The import page's CSRF token, which the export's POST needs. Signed out, Goodreads sends the page to sign in instead
    def csrf_token(http)
      response = http.get('/review/import')
      raise 'Goodreads signed us out: copy a fresh Cookie header into GOODREADS_COOKIE' unless response.success?

      Nokogiri::HTML(response.body).at('meta[name="csrf-token"]')&.[]('content') or
        raise "Goodreads' import page has no CSRF token"
    end

    def client
      raise 'Set GOODREADS_COOKIE to the Cookie header of a signed-in browser' if ENV['GOODREADS_COOKIE'].blank?

      Faraday.new(BASE_URL) do |conn|
        # As .env quotes it, if it's been copied from there with its quotes
        conn.headers['Cookie'] = ENV['GOODREADS_COOKIE'].strip.delete_prefix('"').delete_suffix('"')
        conn.headers['User-Agent'] = USER_AGENT
        conn.headers['X-Requested-With'] = 'XMLHttpRequest'
      end
    end
  end
end
