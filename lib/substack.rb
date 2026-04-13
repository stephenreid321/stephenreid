require 'faraday'
require 'json'
require 'uri'
require 'rack/utils'

# Shared Substack publication API helpers (cookie auth: SUBSTACK_TOKEN + SUBSTACK_PUBLICATION_URL).
module Substack
  USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.2 Safari/605.1.15'

  class << self
    def api_sync_enabled?
      ENV['SUBSTACK_TOKEN'].present? && ENV['SUBSTACK_PUBLICATION_URL'].present?
    end

    def normalize_publication_url(url)
      u = url.to_s.strip
      u.start_with?('http://', 'https://') ? u : "https://#{u}"
    end

    def base_api_url
      "#{normalize_publication_url(ENV['SUBSTACK_PUBLICATION_URL']).chomp('/')}/api/v1"
    end

    def http_client
      Faraday.new do |conn|
        conn.headers['Cookie'] = "substack.sid=#{ENV['SUBSTACK_TOKEN']}"
        conn.headers['Accept'] = 'application/json'
        conn.headers['Content-Type'] = 'application/json'
        conn.headers['User-Agent'] = USER_AGENT
      end
    end

    def safe_json(obj)
      return '' if obj.nil?

      JSON.generate(obj)
    rescue JSON::GeneratorError, Encoding::UndefinedConversionError
      ''
    end

    def substack_homepage(subdomain:, custom_domain:)
      return "https://#{custom_domain}" if custom_domain.present?
      return "https://#{subdomain}.substack.com" if subdomain.present?

      ''
    end

    def fetch_notes_page(conn:, base_api:, cursor:)
      path = cursor ? "/notes?cursor=#{URI.encode_www_form_component(cursor)}" : '/notes'
      request_json(conn, "#{base_api}#{path}")
    end

    def fetch_archive_page(conn:, base_api:, offset:, limit:)
      response = conn.get("#{base_api}/archive?limit=#{limit}&offset=#{offset}")
      raise "HTTP #{response.status}: #{response.body.to_s.byteslice(0, 200)}" unless response.success?

      arr = JSON.parse(response.body.to_s)
      arr.is_a?(Array) ? arr : []
    end

    def fetch_post_detail(conn:, base_api:, slug:, max_attempts: 3)
      s = slug.to_s.strip
      return nil if s.empty?

      path = "#{base_api}/posts/#{Rack::Utils.escape_path(s)}"
      last_detail = nil
      last_error = nil

      max_attempts.times do |attempt|
        response = conn.get(path)
        unless response.success?
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

    private

    def request_json(conn, url)
      response = conn.get(url)
      raise "HTTP #{response.status}: #{response.body.to_s.byteslice(0, 200)}" unless response.success?

      JSON.parse(response.body.to_s)
    end
  end
end
