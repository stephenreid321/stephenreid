require 'test_config'
require 'open3'

# The rules AGENTS.md sets that no linter checks
class LintTest < ActiveSupport::TestCase
  def read(path)
    File.read(File.join(ROOT, path), encoding: 'UTF-8')
  end

  def workflows
    Dir[File.join(ROOT, '.github/workflows/*.yml')].map { |path| File.basename(path) }
  end

  def tracked(*patterns)
    Open3.capture2('git', 'ls-files', '-z', '--', *patterns, chdir: ROOT).first.split("\0")
  end

  # A disable of each linter's, and the reason it must give after it
  DISABLES = {
    /rubocop:disable/ => /rubocop:disable \S+ -- \S/,
    /eslint-disable/ => /eslint-disable(-next-line|-line)? \S+ -- \S/,
    /stylelint-disable/ => /stylelint-disable(-next-line|-line)? \S+ -- \S/,
    /zizmor: ignore/ => /zizmor: ignore\[[\w-]+\] -- \S/,
    /shellcheck disable=/ => /shellcheck disable=SC\d+(,SC\d+)* # \S/
  }.freeze

  # A version npm installs exactly: no range, tag or prefix
  EXACT = /\A\d+\.\d+\.\d+(-[\w.]+)?\z/

  # What's wrong with how a template loads a CDN file, or nil: a script or stylesheet from a CDN not through cdn_tag
  # (which writes its integrity hash), a cdn_tag of an npm package's file by its URL rather than its package and file, or
  # of a package config/frontend_package.json doesn't name
  def cdn_tag_offense(template)
    return 'Load it with {% cdn_tag %}, which writes its integrity hash' if template.match?(%r{<(script|link)\b[^>]*\b(src|href)=["']https://(cdn\.jsdelivr\.net|unpkg\.com|cdnjs\.cloudflare\.com)/}) && !template.include?('rel="preconnect"')

    template.scan(FRONTEND_CDN_TAG).each do |name, file|
      return "Name the package and file: {% cdn_tag 'package', 'path/file.js' %}" if !file && name.start_with?('https://cdn.jsdelivr.net/npm/')
      return "#{name} isn't in config/frontend_package.json" if file && !FRONTEND_VERSIONS.key?(name)
    end
    nil
  end

  # Runs script/lint on these files (but not lint_test, which is running it), and returns what it printed and whether
  # it passed
  def lint(*files)
    output, status = Open3.capture2e({ 'LINT_TEST' => '1' }, 'script/lint', *files, chdir: ROOT)
    [output, status.success?]
  end

  test 'every CDN file the site loads has its hash, and no hash is of a file nothing loads' do
    urls = FRONTEND_CDN_URLS.call(ROOT).uniq

    assert_empty urls - FRONTEND_INTEGRITY.keys, 'run rake frontend:integrity'
    assert_empty FRONTEND_INTEGRITY.keys - urls, 'run rake frontend:integrity'
  end

  test 'every file data/fetched is written to is in a cache, so site.yml has it to build from' do
    cached = read('.github/actions/fetched/action.yml').scan(%r{data/fetched/(\w+)\.json}).flatten
    written = Dir[File.join(ROOT, 'lib/*.rb')].flat_map { |path| File.read(path, encoding: 'UTF-8').scan(/Fetched\.write\(:(\w+)/).flatten }

    assert_equal written.uniq.sort, cached.uniq.sort
  end

  test 'site.yml restores every cache' do
    caches = read('.github/actions/fetched/action.yml').scan(/^\s+(\w+)\) paths=/).flatten

    assert_equal caches.sort, read('.github/workflows/site.yml').scan(/cache: (\w+)/).flatten.sort
  end

  test 'AGENTS.md names each workflow, and no workflow it names is gone' do
    named = read('AGENTS.md')[/^Each is named in the Actions tab.*$/].scan(/`([\w-]+\.yml)`/).flatten

    assert_equal workflows.sort, named.sort
  end

  test 'no workflow has a GitHub schedule, which runs late or not at all: the Cloudflare Worker starts them' do
    workflows.each { |workflow| refute_match(/^\s+schedule:/, read(".github/workflows/#{workflow}"), workflow) }
  end

  test 'Dandelion still finds the files it reads from master' do
    %w[data/goodreads_library_export.csv data/dandelion_books.csv data/films.csv site/images/books].each do |path|
      assert_path_exists File.join(ROOT, path), "Dandelion reads #{path}: keep it there, or change Dandelion with it"
    end
  end

  test 'the compiled stylesheets are compiled, not edited' do
    %w[dark light].each do |theme|
      assert_match(/\A#{Regexp.escape("/* Compiled from #{theme}.scss by `rake stylesheets:build`")}/, read("site/stylesheets/#{theme}.css"))
    end
  end

  test 'each test file has a class of its own, as rake test loads them into one process' do
    classes = Dir[File.join(ROOT, 'test/**/*_test.rb')].flat_map { |path| File.read(path, encoding: 'UTF-8').scan(/^class (\w+)/).flatten }

    assert_equal classes.uniq, classes
  end

  test 'tests reach no outside service: none changes the adapter that refuses what it did not stub' do
    Dir[File.join(ROOT, 'test/**/*.rb')].each do |path|
      next if path.end_with?('setup/outside_services.rb', 'lint_test.rb')

      refute_match(/Faraday\.default_adapter\s*=|Faraday\.default_connection\s*=|Net::HTTP\.start/, File.read(path, encoding: 'UTF-8'), path)
    end
  end

  test 'every disable of a linter says why, after the rule' do
    files = tracked('*.rb', '*.rake', '*.js', '*.mjs', '*.scss', '.github', '.githooks', 'script', 'Gemfile', 'Rakefile') - ['test/lint_test.rb']
    missing = files.flat_map do |path|
      File.readlines(File.join(ROOT, path), encoding: 'UTF-8').each_with_index.filter_map do |line, i|
        "#{path}:#{i + 1}: #{line.strip}" if DISABLES.any? { |disable, with_reason| line.match?(disable) && !line.match?(with_reason) }
      end
    end

    assert_empty missing, 'Say why after the rule: rubocop:disable X -- reason, eslint-disable-next-line x -- reason, ' \
                          'zizmor: ignore[x] -- reason, shellcheck disable=SCn # reason'
  end

  test 'a disable without its reason is caught' do
    assert(DISABLES.any? { |disable, reason| '# rubocop:disable Style/Foo'.match?(disable) && !'# rubocop:disable Style/Foo'.match?(reason) })
    refute(DISABLES.any? { |disable, reason| '# rubocop:disable Style/Foo -- why'.match?(disable) && !'# rubocop:disable Style/Foo -- why'.match?(reason) })
  end

  test 'every package and CDN file is pinned to an exact version' do
    %w[package.json cloudflare/package.json config/frontend_package.json].each do |manifest|
      JSON.parse(read(manifest)).values_at('dependencies', 'devDependencies').compact.reduce({}, :merge).each do |name, version|
        assert_match EXACT, version, "#{manifest}: pin #{name} to an exact version"
      end
    end
    pinned = Dir[File.join(ROOT, 'tasks/*.rake')].flat_map { |f| File.read(f, encoding: 'UTF-8').scan(%r{['"]((?:@[\w.-]+/)?[\w.-]+@[^'"\s]+)['"]}).flatten }

    pinned.reject { |package| package.include?('#{') }.each do |package|
      assert_match EXACT, package.rpartition('@').last, "pin #{package} to an exact version"
    end
  end

  test 'iframe-resizer stays on 4, as 5 and later are GPL-3.0 or a paid licence' do
    assert_match(/\A4\./, FRONTEND_VERSIONS.fetch('iframe-resizer'))
  end

  test 'templates load CDN files with cdn_tag, by package and file' do
    {
      '<script src="https://cdn.jsdelivr.net/npm/x@1.0.0/x.min.js"></script>' => /cdn_tag/,
      %(<script defer src='https://unpkg.com/x@1.0.0/x.js'></script>) => /cdn_tag/,
      '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/x@1.0.0/x.css">' => /cdn_tag/,
      %({% cdn_tag 'https://cdn.jsdelivr.net/npm/jquery@4.0.0/dist/jquery.min.js' %}) => /Name the package and file/,
      %({% cdn_tag 'not-a-package', 'x.min.js' %}) => %r{isn't in config/frontend_package\.json}
    }.each { |template, message| assert_match message, cdn_tag_offense(template).to_s, template }
    [%({% cdn_tag 'chart.js', 'dist/chart.umd.min.js' %}), '<link rel="preconnect" href="https://cdn.jsdelivr.net">',
     '<script src="https://www.googletagmanager.com/gtag/js?id=x"></script>'].each { |template| assert_nil cdn_tag_offense(template), template }

    offenses = (tracked('site/*.html', 'site/*.md') - tracked('site/fonts')).filter_map do |path|
      offense = cdn_tag_offense(read(path))
      "#{path}: #{offense}" if offense
    end

    assert_empty offenses
  end

  test 'tests use the shared helpers rather than doing what they do themselves' do
    helpers = Dir[File.join(ROOT, 'test/helpers/*.rb')].flat_map { |f| File.read(f, encoding: 'UTF-8').scan(/^\s+def (\w+[?!]?)/).flatten }

    assert_equal helpers.uniq, helpers, 'Define each helper once, in test/helpers'
    by_hand = { /Faraday::Adapter::Test::Stubs\.new|OutsideServices\.stubs\s*=/ => 'stub_http', /\bENV\[[^\]]+\]\s*=[^=~]/ => 'with_env',
                /Fetched\.stub\(:(read|write)/ => 'with_fetched', /Rake::Task\[/ => 'run_task' }
    Dir[File.join(ROOT, 'test/**/*_test.rb')].each do |path|
      body = File.read(path, encoding: 'UTF-8')

      helpers.each { |helper| refute_match(/^\s+def #{Regexp.escape(helper)}\b/, body, "#{path} defines #{helper}, which test/helpers has") }
      by_hand.each { |pattern, helper| refute_match pattern, body, "#{path}: use #{helper}" }
    end
  end

  test 'to check something is false, tests use refute, not assert_not or assert !' do
    (Dir[File.join(ROOT, 'test/**/*_test.rb')] - [File.expand_path(__FILE__)]).each do |path|
      refute_match(/\bassert_not\b|\bassert\(?\s*!/, File.read(path, encoding: 'UTF-8'), path)
    end
  end

  test 'script/lint runs each linter on its own files, and fails on an offense' do
    skip 'run npm ci first' unless File.exist?(File.join(ROOT, 'node_modules/.bin/stylelint'))

    output, passed = lint('lib/http.rb', 'site/javascripts/app.js', 'site/stylesheets/_core.scss', '.githooks/pre-commit')

    assert passed, "script/lint failed:\n#{output}"
    assert_match(/Passed: RuboCop, ESLint, ShellCheck, Stylelint\n/, output)

    Dir.mktmpdir('lint', File.join(ROOT, 'test')) do |dir|
      File.write(File.join(dir, 'offense.rb'), "def unused\n  x = 1\nend\n")
      output, passed = lint(File.join(dir, 'offense.rb').delete_prefix("#{ROOT}/"))

      refute passed
      assert_match(%r{Lint/UselessAssignment.*Failed: RuboCop}m, output)
    end
  end
end
