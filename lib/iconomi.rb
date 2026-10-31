# ICONOMI's API, as the account in ICN_API_KEY and ICN_SECRET
class Iconomi
  def self.get(path, parameters = nil)
    Faraday.new(headers: headers('GET', path)).get("https://api.iconomi.com#{path}#{"?#{parameters}" if parameters}").body
  end

  def self.post(path, request_body)
    Faraday.new(headers: headers('POST', path, request_body).merge('Content-Type' => 'application/json'))
           .post("https://api.iconomi.com#{path}", request_body).body
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
end
