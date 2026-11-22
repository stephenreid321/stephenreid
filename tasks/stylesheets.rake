namespace :stylesheets do
  desc 'Compile site/stylesheets/dark.scss and light.scss, with Bootstrap at the version in config/frontend_package.json (needs Node)'
  task :build do
    require 'date'
    require 'json'
    require 'tmpdir'
    require_relative '../lib/cooldown'

    root = File.expand_path('..', __dir__)
    stylesheets_dir = File.join(root, 'site/stylesheets')
    bootstrap = JSON.parse(File.read(File.join(root, 'config/frontend_package.json')))['dependencies'].fetch('bootstrap')
    abort 'rake stylesheets:build needs Node (npm)' unless system('npm --version', out: File::NULL)

    Dir.mktmpdir do |dir|
      # --before keeps to package versions published before the cooldown, as the Gemfile's does
      puts "Installing Bootstrap #{bootstrap} and Dart Sass..."
      system('npm', 'install', '--prefix', dir, '--no-save', '--silent', "--before=#{Cooldown.before}", "bootstrap@#{bootstrap}", 'sass@1.108.1', exception: true)

      %w[dark light].each do |theme|
        css_file = File.join(stylesheets_dir, "#{theme}.css")
        # Bootstrap 5.3 and our themes still use @import and darken/lighten, which Dart Sass warns about
        system(File.join(dir, 'node_modules', '.bin', 'sass'), '--no-source-map', '--style=compressed', '--quiet-deps',
               '--silence-deprecation=import', '--silence-deprecation=global-builtin', '--silence-deprecation=color-functions',
               "--load-path=#{File.join(dir, 'node_modules')}", File.join(stylesheets_dir, "#{theme}.scss"), css_file, exception: true)
        # Compressed output starts with a byte order mark when the CSS has non-ASCII characters: drop it, as it would sit
        # after the header, not at the start of the file
        css = File.read(css_file, encoding: 'UTF-8').delete_prefix("\uFEFF")
        File.write(css_file, "/* Compiled from #{theme}.scss by `rake stylesheets:build`. Don't edit this file. */\n#{css}")
        puts "Wrote site/stylesheets/#{theme}.css"
      end
    end
  end
end
