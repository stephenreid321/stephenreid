require 'digest'
require 'tmpdir'

# The Blygger Studio release the blyg runs (cloudflare/blyg/release.json: its version, and its archive's hash), downloaded
# from GitHub and checked against the release's SHA256SUMS and the pinned hash, for rake blyg:download
module BlyggerRelease
  REPO = 'blygger/blygger-studio'.freeze
  # What wrangler deploy and the upgrade need from the archive
  FILES = %w[worker.js migrations normalize-import-dates.mjs LICENSE README.md].freeze

  class << self
    def dir
      File.join(ROOT, 'cloudflare', 'blyg')
    end

    def pinned
      JSON.parse(File.read(File.join(dir, 'release.json')))
    end

    # Downloads the pinned release, or this version (a new one drops the old hash, so the one downloaded is checked
    # against the release's SHA256SUMS and pinned), checks it, extracts FILES into dir and pins it. Returns the version
    def download(version: nil)
      release = pinned
      version = version.to_s.delete_prefix('v').presence
      release = { 'version' => version } if version && version != release['version']
      version = release['version']

      tag = JSON.parse(get("https://api.github.com/repos/#{REPO}/releases/tags/v#{version}"))
      Cooldown.check!("v#{version}", tag['published_at'])

      assets = tag['assets'].to_h { |a| [a['name'], a['browser_download_url']] }
      archive = "blygger-worker-#{version}.tar.gz"
      body = get(assets.fetch(archive) { raise "v#{version} has no #{archive}" })
      sha256 = Digest::SHA256.hexdigest(body)
      listed = get(assets.fetch('SHA256SUMS')).lines.map(&:split).to_h { |hash, name| [name, hash] }[archive]
      raise "#{archive}: #{sha256}, but SHA256SUMS says #{listed}" unless sha256 == listed
      # The pinned hash wins over the release's, so an archive that's changed since we chose it is refused
      raise "#{archive}: #{sha256}, but release.json pins #{release['sha256']}" if release['sha256'] && release['sha256'] != sha256

      extract(body, "blygger-worker-#{version}")
      File.write(File.join(dir, 'release.json'), "#{JSON.pretty_generate('version' => version, 'sha256' => sha256)}\n")
      version
    end

    # What to do once this version is downloaded
    def next_steps(version)
      <<~TEXT
        Blygger Studio #{version} is in cloudflare/blyg. Read the changelog's Migrations: lines since the last release, then from cloudflare/blyg:
          env -u CLOUDFLARE_API_TOKEN npx wrangler d1 migrations apply DB --remote
          env -u CLOUDFLARE_API_TOKEN node normalize-import-dates.mjs --remote
          env -u CLOUDFLARE_API_TOKEN npx wrangler deploy
      TEXT
    end

    private

    # GitHub's answer, following its redirects to where it keeps the downloads
    def get(url, limit = 5)
      response = Faraday.get(url, nil, { 'Accept' => 'application/octet-stream, application/json', 'User-Agent' => 'stephenreid-site' })
      return get(response.headers['location'], limit - 1) if [301, 302, 303, 307, 308].include?(response.status) && limit.positive?
      raise "#{url}: #{response.status}" unless response.status == 200

      response.body
    end

    # The archive's FILES, from its folder, into dir, the old migrations replaced rather than added to
    def extract(body, folder)
      Dir.mktmpdir do |tmp|
        File.binwrite(File.join(tmp, 'archive.tar.gz'), body)
        system('tar', '-xzf', File.join(tmp, 'archive.tar.gz'), '-C', tmp, exception: true)
        FileUtils.rm_rf(File.join(dir, 'migrations'))
        FILES.each { |name| FileUtils.cp_r(File.join(tmp, folder, name), dir) }
      end
    end
  end
end
