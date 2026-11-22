require 'test_config'

class IconomiTest < ActiveSupport::TestCase
  URL = 'https://api.iconomi.com/v1/strategies/ONE'.freeze

  # Each request it made, in order
  def requests_to(url, *responses)
    made = []
    answer = in_turn(*responses)
    stub_http do |stub|
      stub.get(url) do |env|
        made << env.request_headers.dup
        answer.call(env)
      end
    end
    made
  end

  def get
    Iconomi.stub(:throttle, nil) { Iconomi.get('/v1/strategies/ONE') }
  end

  test 'signs each request with ICN_API_KEY and ICN_SECRET' do
    made = requests_to(URL, [200, {}, '{"ticker":"ONE"}'])
    body = with_env('ICN_API_KEY' => 'key', 'ICN_SECRET' => 'secret') { get }

    assert_equal '{"ticker":"ONE"}', body
    timestamp = made.first['ICN-TIMESTAMP']

    assert_equal [OpenSSL::HMAC.digest('sha512', 'secret', "#{timestamp}GET/v1/strategies/ONE")].pack('m0'), made.first['ICN-SIGN']
    assert_equal 'key', made.first['ICN-API-KEY']
  end

  test 'waits as long as a 429 says, then tries again' do
    made = requests_to(URL, [429, { 'Retry-After' => '7' }, ''], [200, {}, 'ok'])

    assert_equal 'ok', get
    assert_equal 2, made.size
    assert_equal [7.0], OutsideServices.retry_waits
  end

  test 'waits no more than two minutes, however long a 429 says' do
    requests_to(URL, [429, { 'Retry-After' => '3600' }, ''], [200, {}, 'ok'])

    assert_equal 'ok', get
    assert_equal [120.0], OutsideServices.retry_waits
  end

  test 'tries again after an error on ICONOMI\'s side, three times in all' do
    made = requests_to(URL, [502, {}, 'Bad gateway'])

    error = assert_raises(RuntimeError) { get }

    assert_match(%r{HTTP 502 for /v1/strategies/ONE: Bad gateway}, error.message)
    assert_equal 3, made.size
  end

  test 'tries again when the connection drops' do
    attempts = 0
    stub_http do |stub|
      stub.get(URL) do
        attempts += 1
        raise Faraday::ConnectionFailed, 'reset' if attempts == 1

        [200, {}, 'ok']
      end
    end

    assert_equal 'ok', get
    assert_equal 2, attempts
  end

  test "doesn't try again what ICONOMI refuses, such as a strategy whose holdings are private" do
    made = requests_to(URL, [401, {}, 'Unauthorized'])

    assert_raises(RuntimeError) { get }
    assert_equal 1, made.size
  end

  test 'a POST is never tried again, so a rebalance is never made twice' do
    posts = 0
    stub_http { |stub| stub.post('https://api.iconomi.com/v1/strategies/DECENTCOOP/structure') { (posts += 1) && [503, {}, ''] } }

    assert_raises(RuntimeError) { Iconomi.post('/v1/strategies/DECENTCOOP/structure', '{}') }
    assert_equal 1, posts
  end

  test 'keeps under ICONOMI\'s limit of requests a minute, across threads' do
    waits = []
    Iconomi.instance_variable_set(:@next_request_at, nil)
    Iconomi.stub(:sleep, ->(seconds) { waits << seconds }) do
      3.times { Iconomi.throttle }
    end

    assert_equal 2, waits.size
    assert_operator waits.last, :>, 60.0 / Iconomi::REQUESTS_PER_MINUTE
  ensure
    Iconomi.instance_variable_set(:@next_request_at, nil)
  end

  test "lists the strategies ICONOMI's site scores, unlisted ones too, by asking its websocket as the site does" do
    socket = stub_websocket do |message|
      # What the site sends first, then the reply
      [JSON.generate(dataType: 'ticker-prices', payload: {}),
       JSON.generate(dataType: "#{message['dataType']}-response", payload: { 'scores' => [{ 'AAA' => 1.2, 'BBB' => 0.4 }, { 'CCC' => 2.0 }] })]
    end

    assert_equal %w[AAA BBB CCC], Iconomi.strategy_tickers
    assert_equal [Iconomi::SOCKET_URL, { headers: { 'Origin' => 'https://www.iconomi.com' } }], [socket.url, socket.options]
    assert_equal [{ 'dataType' => 'get-sortino-scores', 'payload' => {} }], socket.sent
    assert_predicate socket, :closed?
  end

  test "fails if ICONOMI's websocket errs, closes, or doesn't reply" do
    {
      RuntimeError.new('refused') => /\Arefused\z/,
      nil => /closed the connection/,
      [] => /didn't reply to get-sortino-scores/
    }.each do |reply, message|
      socket = stub_websocket { reply }

      assert_match message, assert_raises(RuntimeError) { Iconomi.socket_request('get-sortino-scores', timeout: 0.01) }.message
      assert_predicate socket, :closed?
    end
  end
end
