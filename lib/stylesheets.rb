require 'tmpdir'

# The site's two themes, compiled from site/stylesheets/<theme>.scss with Dart Sass, and Bootstrap at the version in
# config/frontend_package.json, so the CSS and Bootstrap's JavaScript always match. For rake stylesheets:build
module Stylesheets
  THEMES = %w[dark light].freeze
  # Bootstrap 5.3 and our themes still use @import and darken/lighten, which Dart Sass warns about
  SILENCED = %w[import global-builtin color-functions].freeze

  class << self
    def dir
      File.join(ROOT, 'site', 'stylesheets')
    end

    # Installs Bootstrap and Dart Sass from npm, packages from before the cooldown only, and compiles each theme to
    # its CSS, with a header saying not to edit it
    def build
      bootstrap = FRONTEND_VERSIONS.fetch('bootstrap')
      raise 'rake stylesheets:build needs Node (npm)' unless system('npm --version', out: File::NULL)

      Dir.mktmpdir do |modules|
        puts "Installing Bootstrap #{bootstrap} and Dart Sass..."
        system('npm', 'install', '--prefix', modules, '--no-save', '--silent', "--before=#{Cooldown.before}", "bootstrap@#{bootstrap}", 'sass@1.108.1', exception: true)
        THEMES.each { |theme| compile(theme, File.join(modules, 'node_modules')) }
      end
    end

    private

    def compile(theme, node_modules)
      css_file = File.join(dir, "#{theme}.css")
      system(File.join(node_modules, '.bin', 'sass'), '--no-source-map', '--style=compressed', '--quiet-deps',
             *SILENCED.map { |d| "--silence-deprecation=#{d}" }, "--load-path=#{node_modules}",
             File.join(dir, "#{theme}.scss"), css_file, exception: true)
      # Compressed output starts with a byte order mark when the CSS has non-ASCII characters: drop it, as it would sit
      # after the header, not at the start of the file
      css = File.read(css_file, encoding: 'UTF-8').delete_prefix("\uFEFF")
      File.write(css_file, "/* Compiled from #{theme}.scss by `rake stylesheets:build`. Don't edit this file. */\n#{css}")
      puts "Wrote site/stylesheets/#{theme}.css"
    end
  end
end
