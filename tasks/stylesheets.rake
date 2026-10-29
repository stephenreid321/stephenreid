namespace :stylesheets do
  desc 'Compile app/assets/stylesheets/dark.scss and light.scss, with Bootstrap at the version in frontend/package.json (needs Node)'
  task :build do
    require 'date'
    require 'json'
    require 'tmpdir'

    root = File.expand_path('..', __dir__)
    stylesheets_dir = File.join(root, 'app/assets/stylesheets')
    bootstrap = JSON.parse(File.read(File.join(root, 'frontend/package.json')))['dependencies'].fetch('bootstrap')
    abort 'rake stylesheets:build needs Node (npm)' unless system('npm --version', out: File::NULL)

    Dir.mktmpdir do |dir|
      # --before keeps to package versions published at least 7 days ago, like the Gemfile's cooldown
      puts "Installing Bootstrap #{bootstrap} and Dart Sass..."
      system('npm', 'install', '--prefix', dir, '--no-save', '--silent', "--before=#{(Date.today - 7).iso8601}", "bootstrap@#{bootstrap}", 'sass@1.106.1', exception: true)

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
        puts "Wrote app/assets/stylesheets/#{theme}.css"
      end
    end
  end
end
