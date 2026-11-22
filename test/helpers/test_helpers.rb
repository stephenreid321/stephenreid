# Helpers more than one test file uses, included in every test (test/test_config.rb). A helper only one file uses
# stays in that file
require 'rake'

module TestHelpers
  # Answers requests with these stubs (Faraday's test adapter: stub.get(url) { |env| [status, headers, body] }). Any
  # request they don't match is refused. A stub answers as often as it's matched
  def stub_http(&)
    OutsideServices.stubs = Faraday::Adapter::Test::Stubs.new(&)
  end

  # Fakes the websocket: the block gets each message sent, parsed, and returns the server's replies (see FakeWebsocket).
  # Returns the fake, which keeps what was sent
  def stub_websocket(&reply)
    OutsideServices.websocket = OutsideServices::FakeWebsocket.new(reply)
  end

  # A stub's answer: JSON, with its status and any headers
  def json(body, status = 200, headers = {})
    [status, { 'Content-Type' => 'application/json' }.merge(headers), JSON.generate(body)]
  end

  # Answers a stub with each of these in turn, and the last ever after: a 429 then a 200, say
  def in_turn(*responses)
    queue = responses.dup
    ->(_env) { queue.size > 1 ? queue.shift : queue.first }
  end

  # Runs the block with these environment variables set (nil unsets one), then puts them back
  def with_env(vars)
    before = vars.keys.to_h { |k| [k, ENV.fetch(k, nil)] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    before.each { |k, v| ENV[k] = v }
  end

  # Runs the block with data/fetched holding these files (by name, as Fetched names them) and no others, each as it
  # would be read back from JSON, and returns what the block does
  def with_fetched(files = {})
    files = files.transform_keys(&:to_s).transform_values { |data| JSON.parse(JSON.generate(data)) }
    read = ->(name, default = []) { files.key?(name.to_s) ? files[name.to_s] : default }
    write = ->(name, data) { files[name.to_s] = JSON.parse(JSON.generate(data)) }
    Fetched.stub(:read, read) { Fetched.stub(:write, write) { yield files } }
  end

  # The files of data/fetched after the block, by name: those it wrote, and these it started with
  def fetched_after(files = {}, &block)
    with_fetched(files) do |fetched|
      block.call
      fetched
    end
  end

  # Runs a rake task (tasks/*.rake) as `rake name` would, and returns what it printed
  def run_task(name)
    load_tasks
    task = Rake::Task[name]
    task.all_prerequisite_tasks.each(&:reenable)
    task.reenable
    capture_io { task.invoke }.first
  end

  def load_tasks
    return if Rake::Task.task_defined?('data:fetch')

    Rake.application = Rake::Application.new
    load File.join(ROOT, 'Rakefile')
  end

  # A file in test/fixtures
  def fixture(path)
    File.read(File.join(__dir__, '..', 'fixtures', path), encoding: 'UTF-8')
  end
end
