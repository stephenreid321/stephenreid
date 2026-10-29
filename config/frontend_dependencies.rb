require 'json'

# The version of each npm package the site loads from jsDelivr, from frontend/package.json
FRONTEND_VERSIONS = JSON.parse(File.read(File.expand_path('../frontend/package.json', __dir__)))['dependencies'].freeze

# A file of an npm package on jsDelivr, at the version frontend/package.json names
FRONTEND_NPM_URL = ->(package, file) { "https://cdn.jsdelivr.net/npm/#{package}@#{FRONTEND_VERSIONS.fetch(package)}/#{file}" }

# The hash of each CDN file the site loads, by its URL, from frontend/integrity.json (written by rake frontend:integrity).
# cdn_tag writes it as the file's integrity attribute, so the browser won't run a file that's changed
FRONTEND_INTEGRITY = JSON.parse(File.read(File.expand_path('../frontend/integrity.json', __dir__))).freeze

# The npm packages every page loads from jsDelivr, in order, and their files
FRONTEND_DEPENDENCIES = {
  'jquery' => 'dist/jquery.min.js',
  'bootstrap' => 'dist/js/bootstrap.bundle.min.js',
  'chart.js' => 'dist/chart.umd.min.js',
  'js-cookie' => 'dist/js.cookie.min.js',
  'datatables.net' => 'js/dataTables.min.js',
  'datatables.net-bs5' => 'js/dataTables.bootstrap5.min.js css/dataTables.bootstrap5.min.css',
  'iframe-resizer' => 'js/iframeResizer.min.js',
  'bootstrap-icons' => 'font/bootstrap-icons.min.css',
  'masonry-layout' => 'dist/masonry.pkgd.min.js',
  '@github/relative-time-element' => 'dist/bundle.js'
}.freeze

# Packages whose files are ES modules, loaded with type="module"
FRONTEND_MODULES = %w[@github/relative-time-element].freeze

# Files every page loads that aren't an npm package's, by URL
FRONTEND_URLS = [
  # Dandelion's pagelets.js, at a fixed commit
  'https://cdn.jsdelivr.net/gh/symbiota-coop/dandelion@b2ac10e0761e8d8a2942750f80261a99233d6118/app/assets/javascripts/pagelets.js'
].freeze

# A cdn_tag call in a template: a package and its file (cdn_tag 'chart.js', 'dist/chart.umd.min.js'), or the URL of a
# file that isn't an npm package's
FRONTEND_CDN_TAG = /cdn_tag[ (]+['"]([^'"]+)['"](?:,\s*['"]([^'"]+)['"])?/

# Every CDN file the site loads: FRONTEND_DEPENDENCIES', FRONTEND_URLS and those templates load with cdn_tag. Each has a
# hash in FRONTEND_INTEGRITY
FRONTEND_CDN_URLS = lambda do |root|
  urls = FRONTEND_DEPENDENCIES.flat_map { |package, files| files.split.map { |f| FRONTEND_NPM_URL.call(package, f) } } + FRONTEND_URLS
  urls + Dir[File.join(root, 'app/views/**/*.erb')].flat_map do |f|
    File.read(f, encoding: 'UTF-8').scan(FRONTEND_CDN_TAG).map { |name, file| file ? FRONTEND_NPM_URL.call(name, file) : name }
  end
end
