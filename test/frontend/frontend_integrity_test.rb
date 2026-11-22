require 'test_config'

# lib/frontend_integrity.rb (rake frontend:integrity): the hash of each CDN file the site loads
class FrontendIntegrityTest < ActiveSupport::TestCase
  CHART = 'https://cdn.jsdelivr.net/npm/chart.js@4.6.1/dist/chart.umd.min.js'.freeze
  ICONS = 'https://cdn.jsdelivr.net/npm/@github/relative-time-element@5.3.1/dist/bundle.js'.freeze
  OTHER = 'https://example.com/widget.js'.freeze

  # Runs the block with config/frontend_integrity.json in a temporary folder, holding these hashes, and returns what it
  # holds after, and what was printed
  def with_integrity(hashes, &)
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'frontend_integrity.json')
      File.write(path, JSON.generate(hashes))
      out = FrontendIntegrity.stub(:path, path) { capture_io(&).first }
      [JSON.parse(File.read(path)), out]
    end
  end

  # npm's registry, with when each version was published, and the CDN's files
  def stub_cdn(released: 30.days.ago, files: {})
    stub_http do |stub|
      stub.get("#{FrontendIntegrity::NPM_REGISTRY}chart.js") { json('time' => { '4.6.1' => released.utc.iso8601 }) }
      stub.get("#{FrontendIntegrity::NPM_REGISTRY}@github/relative-time-element") { json('time' => { '5.3.1' => released.utc.iso8601 }) }
      files.each { |url, body| stub.get(url) { [200, {}, body] } }
    end
  end

  def sha384(body)
    "sha384-#{Digest::SHA384.base64digest(body)}"
  end

  test 'hashes each file that has no hash yet, keeps those it has without fetching them again, and drops those nothing loads' do
    stub_cdn(files: { CHART => 'chart', OTHER => 'widget' })
    hashes, out = with_integrity(ICONS => 'sha384-kept', 'https://cdn.jsdelivr.net/npm/gone@1.0.0/x.js' => 'sha384-gone') do
      FrontendIntegrity.update([CHART, ICONS, OTHER, CHART])
    end

    assert_equal({ CHART => sha384('chart'), ICONS => 'sha384-kept', OTHER => sha384('widget') }, hashes)
    # In order, so a new hash is a line of its own in the diff
    assert_equal [ICONS, CHART, OTHER], hashes.keys
    assert_equal "#{CHART}\n#{OTHER}\n", out
  end

  test "refuses a version released within the cooldown, or one npm's registry hasn't, and leaves the hashes as they were" do
    { 2.days.ago => /chart\.js@4\.6\.1: released 2\.0 days ago, under the 7-day cooldown/,
      nil => /chart\.js@4\.6\.1: not on the npm registry/ }.each do |released, message|
      stub_cdn(files: { CHART => 'chart' })
      stub_http { |stub| stub.get("#{FrontendIntegrity::NPM_REGISTRY}chart.js") { json('time' => released ? { '4.6.1' => released.utc.iso8601 } : {}) } }
      error = nil
      hashes, = with_integrity(ICONS => 'sha384-kept') { error = assert_raises(RuntimeError) { FrontendIntegrity.update([CHART, ICONS]) } }

      assert_match message, error.message
      assert_equal({ ICONS => 'sha384-kept' }, hashes)
    end
  end

  test "refuses a file jsDelivr minified itself, as its output can change, and one the CDN or registry won't serve" do
    stub_cdn(files: { CHART => "/**\n * Minified by jsDelivr using Terser v5.39.0.\n */\nchart" })

    assert_match(/minified by jsDelivr, not in the package/, assert_raises(RuntimeError) { with_integrity({}) { FrontendIntegrity.update([CHART]) } }.message)

    stub_cdn
    stub_http { |stub| stub.get(OTHER) { [404, {}, ''] } }

    assert_match(/widget\.js: 404/, assert_raises(RuntimeError) { with_integrity({}) { FrontendIntegrity.update([OTHER]) } }.message)

    stub_http { |stub| stub.get("#{FrontendIntegrity::NPM_REGISTRY}chart.js") { [503, {}, ''] } }

    assert_match(/chart\.js: npm registry 503/, assert_raises(RuntimeError) { with_integrity({}) { FrontendIntegrity.update([CHART]) } }.message)
  end

  test 'hashes every file the site loads, by default' do
    stub_cdn
    hashes, = with_integrity(FRONTEND_INTEGRITY) { FrontendIntegrity.update }

    assert_equal FRONTEND_INTEGRITY.sort.to_h, hashes
  end
end
