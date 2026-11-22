require 'digest'

# config/frontend_integrity.json: the hash of each CDN file the site loads, which cdn_tag writes as its integrity
# attribute, so the browser refuses a file that's changed since we chose it. For rake frontend:integrity
module FrontendIntegrity
  NPM_REGISTRY = 'https://registry.npmjs.org/'.freeze
  # A file of an npm package on jsDelivr: its package and version
  JSDELIVR_NPM = %r{\Ahttps://cdn\.jsdelivr\.net/npm/((?:@[^/]+/)?[^@/]+)@([^/]+)/}

  class << self
    def path
      File.join(ROOT, 'config', 'frontend_integrity.json')
    end

    # Hashes each of these files that has no hash yet, keeps the hashes it has rather than trusting the CDN again, and
    # drops those of files not among them. Refuses a version of an npm package released within the cooldown
    def update(urls = FRONTEND_CDN_URLS.call(ROOT))
      # Read from the file rather than FRONTEND_INTEGRITY, which was loaded at boot
      existing = File.exist?(path) ? JSON.parse(File.read(path)) : {}
      # When each version of a package was published, fetched once a package
      release_times = Hash.new { |times, package| times[package] = release_times_of(package) }

      hashes = urls.uniq.sort.to_h do |url|
        next [url, existing[url]] if existing[url]

        # Hashing a version pins whatever it is, so refuse one released within the cooldown
        if (match = url.match(JSDELIVR_NPM))
          package, version = match.captures
          released = release_times[package][version] or raise "#{package}@#{version}: not on the npm registry"
          Cooldown.check!("#{package}@#{version}", released)
        end
        puts url
        [url, hash_of(url)]
      end

      File.write(path, "#{JSON.pretty_generate(hashes)}\n")
      hashes
    end

    private

    def release_times_of(package)
      response = Faraday.get("#{NPM_REGISTRY}#{package}")
      raise "#{package}: npm registry #{response.status}" unless response.status == 200

      JSON.parse(response.body)['time']
    end

    def hash_of(url)
      response = Faraday.get(url)
      raise "#{url}: #{response.status}" unless response.status == 200
      # jsDelivr minifies a .min file a package doesn't have itself, and its output can change: load the package's own file
      raise "#{url}: minified by jsDelivr, not in the package" if response.body[0, 500].include?('Minified by jsDelivr')

      "sha384-#{Digest::SHA384.base64digest(response.body)}"
    end
  end
end
