namespace :blyg do
  desc 'Publish to the blyg the links archived in Readwise in the last week since the newest one on it, as bluesky:post posts them to Bluesky (needs READWISE_ACCESS_TOKEN and BLYG_ACCESS_TOKEN)'
  task post: :environment do
    blyg = Blyg.new
    posted_urls = Blyg.recent_link_urls.map { |url| Readwise.clean_url(url) }
    archived = Readwise.archived_since(7.days.ago).last(50)

    # Only those archived after the newest that's on the blyg already, so a link never lands above ones archived after
    # it: one missed is left out rather than posted out of order
    newest_posted = archived.rindex { |r| posted_urls.include?(r['source_url']) }
    archived = archived.drop(newest_posted + 1) if newest_posted

    # Oldest first, so the newest archive item is last and sits on top of the blyg
    archived.each do |r|
      url = r['source_url']
      next if posted_urls.include?(url)

      puts url
      blyg.post_link(url: url, title: r['title'].presence || url, author: r['author'])
      posted_urls << url
    end
  end

  desc 'Download the Blygger Studio release in cloudflare/blyg/release.json and extract its Worker into cloudflare/blyg, for wrangler deploy. VERSION=x.y.z moves release.json to that release'
  task :download do
    require 'faraday'
    require 'json'
    require 'digest'
    require 'time'
    require 'tmpdir'
    dir = File.expand_path('../cloudflare/blyg', __dir__)
    path = File.join(dir, 'release.json')
    release = JSON.parse(File.read(path))
    # A new version drops the old hash, so the one downloaded below is checked against the release's SHA256SUMS and pinned
    release = { 'version' => ENV['VERSION'].delete_prefix('v') } if ENV['VERSION'] && ENV['VERSION'].delete_prefix('v') != release['version']
    version = release['version']

    get = lambda do |url, limit = 5|
      response = Faraday.get(url, nil, { 'Accept' => 'application/octet-stream, application/json', 'User-Agent' => 'stephenreid-site' })
      next get.call(response.headers['location'], limit - 1) if [301, 302, 303, 307, 308].include?(response.status) && limit.positive?
      raise "#{url}: #{response.status}" unless response.status == 200

      response.body
    end

    tag = JSON.parse(get.call("https://api.github.com/repos/blygger/blygger-studio/releases/tags/v#{version}"))
    # AGENTS.md's cooldown: never a release less than 7 days old
    age = Time.now - Time.parse(tag['published_at'])
    raise "v#{version}: released #{format('%.1f', age / 86_400)} days ago, under the 7-day cooldown" if age < 7 * 86_400

    assets = tag['assets'].to_h { |a| [a['name'], a['browser_download_url']] }
    archive = "blygger-worker-#{version}.tar.gz"
    body = get.call(assets.fetch(archive) { raise "v#{version} has no #{archive}" })
    sha256 = Digest::SHA256.hexdigest(body)
    listed = get.call(assets.fetch('SHA256SUMS')).lines.map(&:split).to_h { |hash, name| [name, hash] }[archive]
    raise "#{archive}: #{sha256}, but SHA256SUMS says #{listed}" unless sha256 == listed
    # The pinned hash wins over the release's, so an archive that's changed since we chose it is refused
    raise "#{archive}: #{sha256}, but release.json pins #{release['sha256']}" if release['sha256'] && release['sha256'] != sha256

    Dir.mktmpdir do |tmp|
      File.binwrite(File.join(tmp, archive), body)
      system('tar', '-xzf', File.join(tmp, archive), '-C', tmp, exception: true)
      extracted = File.join(tmp, "blygger-worker-#{version}")
      FileUtils.rm_rf(File.join(dir, 'migrations'))
      %w[worker.js migrations normalize-import-dates.mjs LICENSE README.md].each do |name|
        FileUtils.cp_r(File.join(extracted, name), dir)
      end
    end

    File.write(path, "#{JSON.pretty_generate('version' => version, 'sha256' => sha256)}\n")
    puts "Blygger Studio #{version} is in cloudflare/blyg. Read the changelog's Migrations: lines since the last release, then from cloudflare/blyg:"
    puts '  env -u CLOUDFLARE_API_TOKEN npx wrangler d1 migrations apply DB --remote'
    puts '  env -u CLOUDFLARE_API_TOKEN node normalize-import-dates.mjs --remote'
    puts '  env -u CLOUDFLARE_API_TOKEN npx wrangler deploy'
  end
end
