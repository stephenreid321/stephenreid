# ICONOMI's API, as the account in ICN_API_KEY and ICN_SECRET
class Iconomi
  # The websocket iconomi.com gets its data from. It isn't documented, and needs no account
  SOCKET_URL = 'wss://www.iconomi.com/websocket/v2'.freeze

  # ICONOMI allows a key 600 requests a minute, then answers 429 for a minute: this keeps under it, across threads
  REQUESTS_PER_MINUTE = 540
  THROTTLE = Mutex.new

  def self.get(path, parameters = nil, attempts: 3)
    throttle
    response = Faraday.new(headers: headers('GET', path)).get("https://api.iconomi.com#{path}#{"?#{parameters}" if parameters}")
    if response.status == 429 && attempts > 1
      sleep response.headers['retry-after'].to_i.clamp(1, 120)
      return get(path, parameters, attempts: attempts - 1)
    end
    raise "HTTP #{response.status} for #{path}: #{response.body.to_s[0, 200]}" unless response.success?

    response.body
  end

  # Waits until it's time for the next request
  def self.throttle
    THROTTLE.synchronize do
      @next_request_at = [@next_request_at || Time.now, Time.now].max
      sleep(@next_request_at - Time.now) if @next_request_at > Time.now
      @next_request_at += 60.0 / REQUESTS_PER_MINUTE
    end
  end

  # Raises if ICONOMI refuses it, so a rebalance it turns down fails rather than passing quietly
  def self.post(path, request_body)
    response = Faraday.new(headers: headers('POST', path, request_body).merge('Content-Type' => 'application/json'))
                      .post("https://api.iconomi.com#{path}", request_body)
    raise "HTTP #{response.status} for #{path}: #{response.body.to_s[0, 500]}" unless response.success?

    response.body
  end

  # A request's headers, signed with ICN_SECRET
  def self.headers(method, path, request_body = '')
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
  def self.strategy_tickers
    socket_request('get-sortino-scores').fetch('scores').flat_map(&:keys)
  end

  # Sends the site's websocket a message of this type and returns the payload of its reply
  def self.socket_request(data_type, payload = {}, timeout: 30)
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
end
