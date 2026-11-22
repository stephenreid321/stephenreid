require 'test_config'

# rake blyg:download (lib/blygger_release.rb): the Blygger Studio release the blyg runs, downloaded from GitHub and
# checked before it's deployed
class BlygDownloadTest < ActiveSupport::TestCase
  API = 'https://api.github.com/repos/blygger/blygger-studio/releases/tags'.freeze
  DOWNLOADS = 'https://github.com/blygger/blygger-studio/releases/download'.freeze

  # A release's archive, as Blygger builds it: its files in a folder of the version's name
  def archive(version, worker: "// Blygger #{version}")
    Dir.mktmpdir do |tmp|
      folder = File.join(tmp, "blygger-worker-#{version}")
      FileUtils.mkdir_p(File.join(folder, 'migrations'))
      File.write(File.join(folder, 'worker.js'), worker)
      File.write(File.join(folder, 'migrations', '0002_new.sql'), 'CREATE TABLE new (id);')
      %w[normalize-import-dates.mjs LICENSE README.md].each { |name| File.write(File.join(folder, name), name) }
      system('tar', '-czf', File.join(tmp, 'archive.tar.gz'), '-C', tmp, "blygger-worker-#{version}", exception: true)
      File.binread(File.join(tmp, 'archive.tar.gz'))
    end
  end

  def sha256(body)
    Digest::SHA256.hexdigest(body)
  end

  # GitHub, with this release: published days ago, its archive (by way of a redirect, as GitHub's downloads are) and
  # its SHA256SUMS, which lists sums for it
  def stub_github(version, body, published: 30.days.ago, sums: sha256(body), assets: ["blygger-worker-#{version}.tar.gz", 'SHA256SUMS'])
    stub_http do |stub|
      stub.get("#{API}/v#{version}") do
        json('published_at' => published.utc.iso8601, 'assets' => assets.map { |name| { 'name' => name, 'browser_download_url' => "#{DOWNLOADS}/v#{version}/#{name}" } })
      end
      stub.get("#{DOWNLOADS}/v#{version}/blygger-worker-#{version}.tar.gz") { [302, { 'Location' => "https://objects.githubusercontent.com/#{version}.tar.gz" }, ''] }
      stub.get("https://objects.githubusercontent.com/#{version}.tar.gz") { [200, {}, body] }
      stub.get("#{DOWNLOADS}/v#{version}/SHA256SUMS") { [200, {}, "#{sums}  blygger-worker-#{version}.tar.gz\nabc  other.zip\n"] }
    end
  end

  # Runs the block with cloudflare/blyg a temporary folder, pinned to this release and with an old migration in it
  def in_blyg_dir(release)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'release.json'), JSON.generate(release))
      FileUtils.mkdir_p(File.join(dir, 'migrations'))
      File.write(File.join(dir, 'migrations', '0001_gone.sql'), '')
      BlyggerRelease.stub(:dir, dir) { yield dir }
    end
  end

  def download(version: nil)
    with_env('VERSION' => version) { run_task('blyg:download') }
  end

  test 'downloads the pinned release, checks it, and extracts its Worker, the old migrations replaced, for wrangler deploy' do
    body = archive('0.59.0')
    stub_github('0.59.0', body)
    in_blyg_dir('version' => '0.59.0', 'sha256' => sha256(body)) do |dir|
      out = download

      assert_equal '// Blygger 0.59.0', File.read(File.join(dir, 'worker.js'))
      assert_equal %w[0002_new.sql], Dir.children(File.join(dir, 'migrations'))
      BlyggerRelease::FILES.each { |name| assert_path_exists File.join(dir, name) }
      assert_equal({ 'version' => '0.59.0', 'sha256' => sha256(body) }, JSON.parse(File.read(File.join(dir, 'release.json'))))
      assert_match(%r{\ABlygger Studio 0\.59\.0 is in cloudflare/blyg.*wrangler d1 migrations apply.*wrangler deploy\n\z}m, out)
    end
  end

  test 'VERSION moves to that release and pins its hash, as SHA256SUMS lists it' do
    body = archive('0.60.0')
    stub_github('0.60.0', body)
    in_blyg_dir('version' => '0.59.0', 'sha256' => 'the old hash') do |dir|
      download(version: 'v0.60.0')

      assert_equal({ 'version' => '0.60.0', 'sha256' => sha256(body) }, JSON.parse(File.read(File.join(dir, 'release.json'))))
      assert_equal '// Blygger 0.60.0', File.read(File.join(dir, 'worker.js'))
    end
  end

  # What it refuses, and leaves cloudflare/blyg as it was
  def assert_refused(message, release, version: nil)
    in_blyg_dir(release) do |dir|
      error = assert_raises(RuntimeError) { download(version: version) }

      assert_match message, error.message
      assert_equal release, JSON.parse(File.read(File.join(dir, 'release.json')))
      refute_path_exists File.join(dir, 'worker.js')
      assert_equal %w[0001_gone.sql], Dir.children(File.join(dir, 'migrations'))
    end
  end

  test 'refuses a release under a week old, by the cooldown' do
    stub_github('0.61.0', archive('0.61.0'), published: 2.days.ago)

    assert_refused(/v0\.61\.0: released 2\.0 days ago, under the 7-day cooldown/, { 'version' => '0.59.0', 'sha256' => 'x' }, version: '0.61.0')
  end

  test "refuses an archive that isn't the one the release's SHA256SUMS lists" do
    body = archive('0.60.0')
    stub_github('0.60.0', body, sums: sha256('something else'))

    assert_refused(/blygger-worker-0\.60\.0\.tar\.gz: #{sha256(body)}, but SHA256SUMS says/, { 'version' => '0.60.0' })
  end

  test "refuses an archive that's changed since it was pinned, even if the release's SHA256SUMS has changed with it" do
    pinned = archive('0.59.0')
    changed = archive('0.59.0', worker: '// something else')
    stub_github('0.59.0', changed)

    assert_refused(/#{sha256(changed)}, but release.json pins #{sha256(pinned)}/, { 'version' => '0.59.0', 'sha256' => sha256(pinned) })
  end

  test "fails if the release has no archive, or GitHub hasn't the release" do
    stub_github('0.59.0', '', assets: ['SHA256SUMS'])

    assert_refused(/v0\.59\.0 has no blygger-worker-0\.59\.0\.tar\.gz/, { 'version' => '0.59.0' })

    stub_http { |stub| stub.get("#{API}/v9.9.9") { [404, {}, '{}'] } }

    assert_refused(%r{releases/tags/v9\.9\.9: 404}, { 'version' => '9.9.9' })
  end
end
