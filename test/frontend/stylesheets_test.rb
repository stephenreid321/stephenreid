require 'test_config'

# lib/stylesheets.rb (rake stylesheets:build): the themes, compiled with Dart Sass and Bootstrap from npm
class FrontendStylesheetsTest < ActiveSupport::TestCase
  # npm and Dart Sass, as Stylesheets runs them: npm is there unless not, its install records what it installed, and
  # Sass compiles each theme to this CSS, with a byte order mark, as it writes one when the CSS has non-ASCII characters
  def fake_node(commands, npm: true)
    lambda do |*args, **_options|
      commands << args
      next npm if args == ['npm --version']

      File.write(args.last, "\uFEFF.#{File.basename(args[-2], '.scss')}{content:\"→\"}") if args.first.end_with?('/sass')
      true
    end
  end

  def build(npm: true)
    commands = []
    Dir.mktmpdir do |dir|
      Stylesheets.stub(:dir, dir) do
        Stylesheets.stub(:system, fake_node(commands, npm: npm)) { capture_io { Stylesheets.build } }
      end
      [commands, Stylesheets::THEMES.to_h { |theme| [theme, File.exist?(File.join(dir, "#{theme}.css")) && File.read(File.join(dir, "#{theme}.css"), encoding: 'UTF-8')] }]
    end
  end

  test 'installs Bootstrap at the version the site loads, and Dart Sass, from before the cooldown' do
    install = build.first.find { |args| args[0, 2] == %w[npm install] }

    assert_includes install, "--before=#{Cooldown.before}"
    assert_includes install, "bootstrap@#{FRONTEND_VERSIONS.fetch('bootstrap')}"
    assert(install.any? { |arg| arg.match?(/\Asass@\d+\.\d+\.\d+\z/) })
  end

  test 'compiles each theme with what it installed, headed as compiled, not to be edited, with no byte order mark' do
    commands, css = build
    sass = commands.select { |args| args.first.end_with?('/sass') }

    assert_equal(%w[dark.scss light.scss], sass.map { |args| File.basename(args[-2]) })
    assert(sass.all? { |args| args.include?('--style=compressed') && args.any? { |a| a.start_with?('--load-path=') && a.end_with?('/node_modules') } })
    assert_equal({ 'dark' => %(/* Compiled from dark.scss by `rake stylesheets:build`. Don't edit this file. */\n.dark{content:"→"}),
                   'light' => %(/* Compiled from light.scss by `rake stylesheets:build`. Don't edit this file. */\n.light{content:"→"}) }, css)
  end

  test 'fails without Node, compiling nothing' do
    error = assert_raises(RuntimeError) { build(npm: false) }

    assert_equal 'rake stylesheets:build needs Node (npm)', error.message
  end
end
