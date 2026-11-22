require 'test_config'

class GoodreadsTest < ActiveSupport::TestCase
  BASE = 'https://www.goodreads.com'.freeze
  EXPORT = "#{BASE}/review_porter/export/#{Goodreads::USER_ID}".freeze
  CSV_BODY = "Book Id,Title,Author\n1,A book,Someone\n2,Another,Someone else\n".freeze

  def export(cookie: '"session=abc"')
    written = nil
    out = with_env('GOODREADS_COOKIE' => cookie) do
      File.stub(:write, ->(path, body) { written = [path, body] }) do
        Goodreads.stub(:sleep, nil) { capture_io { Goodreads.fetch }.first }
      end
    end
    [out, written]
  end

  test 'asks for a new export as the signed-in browser, waits until it is ready, and saves it' do
    heads = in_turn([404, {}, ''], [404, {}, ''], [200, {}, ''])
    started = nil
    stub_http do |stub|
      stub.get("#{BASE}/review/import") { [200, {}, '<meta name="csrf-token" content="tok">'] }
      stub.post(EXPORT) do |env|
        started = env.request_headers
        [200, {}, '']
      end
      stub.head("#{EXPORT}/goodreads_export.csv") { |env| heads.call(env) }
      stub.get("#{EXPORT}/goodreads_export.csv") { [200, {}, CSV_BODY.dup] }
    end

    out, (path, body) = export

    assert_equal "Goodreads: 2 books\n", out
    assert_equal Goodreads::EXPORT_PATH, path
    assert_equal CSV_BODY, body
    # The cookie as .env quotes it, without its quotes
    assert_equal ['tok', 'session=abc', Http::BROWSER_USER_AGENT], started.values_at('X-CSRF-Token', 'Cookie', 'User-Agent')
  end

  test 'says to copy a fresh cookie when Goodreads has signed the session out' do
    stub_http { |stub| stub.get("#{BASE}/review/import") { [302, { 'Location' => "#{BASE}/user/sign_in" }, ''] } }

    error = assert_raises(RuntimeError) { export }

    assert_match(/copy a fresh Cookie header into GOODREADS_COOKIE/, error.message)
  end

  test "refuses what isn't the library's CSV, rather than saving it over the last" do
    stub_http do |stub|
      stub.get("#{BASE}/review/import") { [200, {}, '<meta name="csrf-token" content="tok">'] }
      stub.post(EXPORT) { [200, {}, ''] }
      stub.head("#{EXPORT}/goodreads_export.csv") { [200, {}, ''] }
      stub.get("#{EXPORT}/goodreads_export.csv") { [200, {}, '<html>Sign in</html>'] }
    end

    assert_match(/isn't the library CSV/, assert_raises(RuntimeError) { export }.message)
  end

  test 'needs GOODREADS_COOKIE' do
    assert_match(/Set GOODREADS_COOKIE/, assert_raises(RuntimeError) { export(cookie: '') }.message)
  end
end
