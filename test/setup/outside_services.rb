# What tests don't reach outside: no request leaves the machine. Every Faraday connection, Faraday.get's too, goes
# through Faraday's test adapter, which answers only what the test stubbed (stub_http) and raises
# Faraday::Adapter::Test::Stubs::NotFound for anything else. ICONOMI's websocket is refused, unless a test fakes it
module OutsideServices
  class << self
    # The stubs every connection answers from, whenever it was made: a connection lib/ keeps (SubstackSurfacer's, one a
    # thread) answers this test's stubs, not those of the test that made it
    attr_accessor :stubs

    # How long faraday-retry would have waited before each retry, in seconds. Tests don't wait
    attr_reader :retry_waits

    # The fake websocket connections are made to (stub_websocket), or nil, refusing them
    attr_accessor :websocket

    def reset!
      @stubs = Faraday::Adapter::Test::Stubs.new
      @retry_waits = []
      @websocket = nil
    end
  end

  # Faraday's test adapter, answering from OutsideServices.stubs
  module CurrentStubs
    def stubs
      OutsideServices.stubs
    end
  end

  # faraday-retry's wait, recorded rather than slept
  module RecordedWaits
    def sleep(seconds)
      OutsideServices.retry_waits << seconds
    end
  end

  module RefusedWebsocket
    def connect(url, ...)
      return OutsideServices.websocket.connect(url, ...) if OutsideServices.websocket

      raise "A test tried to reach #{url}: fake it with stub_websocket, or stub what reads from it (Iconomi.strategy_tickers)"
    end
  end

  # A websocket server, as WebSocket::Client::Simple's client sees it: it opens, and answers each message sent with
  # what reply gives (a JSON string, a list of them, or an error, which it reports with :error), or closes
  class FakeWebsocket
    Message = Struct.new(:data)

    attr_reader :url, :options, :sent

    def initialize(reply)
      @reply = reply
      @sent = []
      @closed = false
    end

    def connect(url, options = {})
      @url = url
      @options = options
      @handlers = {}
      yield self
      emit(:open)
      self
    end

    def on(event, &handler)
      @handlers[event] = handler
    end

    def send(data)
      @sent << JSON.parse(data)
      case (reply = @reply.call(@sent.last))
      when nil then emit(:close)
      when Exception then emit(:error, reply)
      else Array(reply).each { |message| emit(:message, Message.new(message)) }
      end
    end

    def close
      @closed = true
    end

    def closed?
      @closed
    end

    private

    def emit(event, *)
      @handlers[event]&.call(*)
    end
  end
end

Faraday.default_adapter = :test
Faraday.default_connection = nil
Faraday::Adapter::Test.prepend(OutsideServices::CurrentStubs)
Faraday::Retry::Middleware.prepend(OutsideServices::RecordedWaits)
WebSocket::Client::Simple.singleton_class.prepend(OutsideServices::RefusedWebsocket)
OutsideServices.reset!
