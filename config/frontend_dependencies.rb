require 'json'

# The version of each npm package the site loads from jsDelivr, from config/frontend_package.json
FRONTEND_VERSIONS = JSON.parse(File.read(File.expand_path('frontend_package.json', __dir__)))['dependencies'].freeze

# A file of an npm package on jsDelivr, at the version config/frontend_package.json names
FRONTEND_NPM_URL = ->(package, file) { "https://cdn.jsdelivr.net/npm/#{package}@#{FRONTEND_VERSIONS.fetch(package)}/#{file}" }

# The hash of each CDN file the site loads, by its URL, from config/frontend_integrity.json (written by rake frontend:integrity).
# The cdn_tag Liquid tag (site/_plugins/site.rb) writes it as the file's integrity attribute, so the browser won't run a file that's changed
FRONTEND_INTEGRITY = JSON.parse(File.read(File.expand_path('frontend_integrity.json', __dir__))).freeze

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
FRONTEND_URLS = [].freeze

# A cdn_tag in a template: a package and its file ({% cdn_tag 'chart.js', 'dist/chart.umd.min.js' %}), or the URL of a
# file that isn't an npm package's
FRONTEND_CDN_TAG = /cdn_tag[ (]+['"]([^'"]+)['"](?:,\s*['"]([^'"]+)['"])?/

# Every CDN file the site loads: FRONTEND_DEPENDENCIES', FRONTEND_URLS and those templates load with cdn_tag. Each has a
# hash in FRONTEND_INTEGRITY
FRONTEND_CDN_URLS = lambda do |root|
  urls = FRONTEND_DEPENDENCIES.flat_map { |package, files| files.split.map { |f| FRONTEND_NPM_URL.call(package, f) } } + FRONTEND_URLS
  urls + Dir[File.join(root, 'site/**/*.{html,md}')].flat_map do |f|
    File.read(f, encoding: 'UTF-8').scan(FRONTEND_CDN_TAG).map { |name, file| file ? FRONTEND_NPM_URL.call(name, file) : name }
  end
end
