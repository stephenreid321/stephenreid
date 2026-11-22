# ICONOMI's API, as the account in ICN_API_KEY and ICN_SECRET
class Iconomi
  API = 'https://api.iconomi.com'.freeze
  # The websocket iconomi.com gets its data from. It isn't documented, and needs no account
  SOCKET_URL = 'wss://www.iconomi.com/websocket/v2'.freeze

  # ICONOMI allows a key 600 requests a minute, then answers 429 for a minute: this keeps under it, across threads
  REQUESTS_PER_MINUTE = 540
  THROTTLE = Mutex.new

  # Tries again what might work a second time (a 429, after as long as it says, up to two minutes; an error on
  # ICONOMI's side; a dropped connection), three times in all, but not a refusal, such as the 401 for a strategy whose
  # holdings are private. Nor a POST, so a rebalance is never made twice
  RETRY = {
    max: 2, interval: 2, max_interval: 120,
    retry_statuses: [429, 500, 502, 503, 504],
    exceptions: [Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::RetriableResponse],
    header_parser_block: ->(retry_after) { retry_after.to_f.clamp(1, 120) if retry_after }
  }.freeze

  # Throttles and signs each request, each try again too, as its signature is of the time it's sent
  class Signature < Faraday::Middleware
    def on_request(env)
      Iconomi.throttle
      env.request_headers.merge!(Iconomi.headers(env.method.to_s.upcase, env.url.path, env.body.to_s))
    end
  end

  class << self
    def get(path)
      request(:get, path)
    end

    def get_json(path)
      JSON.parse(get(path))
    end

    # Raises if ICONOMI refuses it, so a rebalance it turns down fails rather than passing quietly
    def post(path, request_body)
      request(:post, path, request_body, 'Content-Type' => 'application/json')
    end

    # Waits until it's time for the next request
    def throttle
      THROTTLE.synchronize do
        @next_request_at = [@next_request_at || Time.now, Time.now].max
        sleep(@next_request_at - Time.now) if @next_request_at > Time.now
        @next_request_at += 60.0 / REQUESTS_PER_MINUTE
      end
    end

    # A request's headers, signed with ICN_SECRET
    def headers(method, path, request_body = '')
      t = DateTime.now.strftime('%Q')
      signature = OpenSSL::HMAC.digest('sha512', ENV['ICN_SECRET'].to_s, t + method + path + request_body)
      {
        'ICN-API-KEY' => ENV['ICN_API_KEY'],
        'ICN-SIGN' => [signature].pack('m0'), # base64, without newlines
        'ICN-TIMESTAMP' => t
      }
    end

    # Every strategy's ticker, unlisted ones too: /v1/strategies lists only those ICONOMI features, but the site's
    # risk scores (get-sortino-scores) cover them all
    def strategy_tickers
      socket_request('get-sortino-scores').fetch('scores').flat_map(&:keys)
    end

    # Sends the site's websocket a message of this type and returns the payload of its reply
    def socket_request(data_type, payload = {}, timeout: 30)
      replies = Queue.new
      socket = WebSocket::Client::Simple.connect(SOCKET_URL, headers: { 'Origin' => 'https://www.iconomi.com' }) do |ws|
        ws.on(:open) { ws.send(JSON.generate(dataType: data_type, payload: payload)) }
        ws.on(:message) { |message| replies << message.data }
        ws.on(:error) { |e| replies << e }
        ws.on(:close) { |e| replies << (e || RuntimeError.new("ICONOMI's websocket closed the connection")) }
      end
      loop do
        reply = replies.pop(timeout: timeout) || raise("ICONOMI's websocket didn't reply to #{data_type}")
        raise reply if reply.is_a?(Exception)

        message = JSON.parse(reply)
        return message['payload'] if message['dataType'].to_s.start_with?(data_type)
      end
    ensure
      socket&.close
    end

    private

    def request(method, path, body = nil, headers = nil)
      response = connection.run_request(method, path, body, headers)
      raise "HTTP #{response.status} for #{path}: #{response.body.to_s[0, 500]}" unless response.success?

      response.body
    end

    def connection
      @connection ||= Faraday.new(API) do |f|
        f.request :retry, RETRY
        f.use Signature
      end
    end
  end
end
