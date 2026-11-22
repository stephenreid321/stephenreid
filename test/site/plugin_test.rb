require 'test_config'
require 'jekyll'
require File.join(ROOT, 'site/_plugins/site')

# site/_plugins/site.rb: what the templates get, and the pages made without a template of their own
class SitePluginTest < ActiveSupport::TestCase
  def site
    @site ||= Jekyll::Site.new(Jekyll.configuration('source' => File.join(ROOT, 'site'), 'destination' => Dir.mktmpdir, 'quiet' => true))
  end

  def generated_pages
    with_fetched(courses: {}) { StephenReid::Pages.new.generate(site) }
    site.pages.to_h { |page| [page.url, page] }
  end

  test "a CDN file's tag carries the hash it was chosen with, so the browser refuses it if it changes" do
    url = FRONTEND_NPM_URL.call('chart.js', 'dist/chart.umd.min.js')

    assert_equal %(<script integrity="#{FRONTEND_INTEGRITY.fetch(url)}" crossorigin="anonymous" src="#{url}"></script>),
                 StephenReid.cdn_tag('chart.js', 'dist/chart.umd.min.js')
    assert_match(/\A<link integrity="sha384-[^"]+" crossorigin="anonymous" rel="stylesheet" href=/, StephenReid.cdn_tag('bootstrap-icons', 'font/bootstrap-icons.min.css'))
    # One with no hash isn't loaded at all
    assert_raises(KeyError) { StephenReid.cdn_tag('chart.js', 'dist/chart.js') }
  end

  test 'every page loads the ES modules as modules' do
    tags = StephenReid::CdnDependencies.parse('cdn_dependencies', '', Liquid::Tokenizer.new(''), Liquid::ParseContext.new).render(nil)

    assert_match(%r{<script type="module" integrity="[^"]+" crossorigin="anonymous" src="[^"]+/@github/relative-time-element@[^"]+"></script>}, tags)
    assert_equal FRONTEND_DEPENDENCIES.values.sum { |files| files.split.size }, tags.lines.size
  end

  test 'redirects each short URL, and each book to Goodreads, with a page that says where it goes' do
    pages = generated_pages

    assert_includes pages['/cal.html'].content, '<meta http-equiv="refresh" content="0; url=https://cal.com/stephenreid">'
    book = BOOKS.first

    assert_includes pages["/books/#{book[:slug]}.html"].content, "https://www.goodreads.com/book/show/#{book[:book_id]}"
    assert_includes pages['/context.txt'].content, '## Short bio in the third person'
  end

  test "makes a page of each course's notes, and warns of those not fetched" do
    course = COURSES.first
    site
    with_fetched(courses: { course[:slug] => { 'head' => '<style></style>', 'body' => '<p>Notes</p>' } }) do
      warnings = []
      Jekyll.logger.stub(:warn, ->(*message) { warnings << message.join(' ') }) { StephenReid::Pages.new.generate(site) }

      page = site.pages.find { |p| p.url == "/courses/#{course[:slug]}.html" }

      assert_equal ['<p>Notes</p>', 'course', '<style></style>'], [page.content, page.data['layout'], page.data['head']]
      assert_equal COURSES.drop(1).map { |c| "Courses: no notes for #{c[:name]}: run rake data:courses" }, warnings
    end
  end

  test 'hands the templates the books read, newest first, and the films and speaking engagements not hidden' do
    data = with_fetched(places: [{ 'name' => 'Communities', 'places' => [] }]) { StephenReid::SiteData.for_templates }
    books = data['books']
    read = BOOKS.select { |b| b[:date_read] }

    assert_equal read.size, books.size
    assert_equal read.map { |b| b[:date_read] }.max, BOOKS.find { |b| b[:book_id] == books.first['book_id'] }[:date_read]
    assert_equal %w[book_id title cover_image tooltip], books.first.keys
    assert_match(/\ARead [A-Z][a-z]{2} \d{4}\z/, books.first['tooltip'])
    # None before 2020, when Stephen started noting when
    assert_nil books.last['tooltip']
    assert_equal FILMS.size, data['films'].size
    assert_equal SPEAKING_ENGAGEMENTS.count { |s| !s[:hidden] }, data['speaking_engagements'].size
    assert_equal [{ 'name' => 'Communities', 'places' => [] }], data['places']
    assert_match(/\A\d{4}-\d{2}-\d{2}T/, data['books_updated'])
  end

  test "gives each speaking engagement the icon of the site it's on, or none" do
    icons = with_fetched { StephenReid::SiteData.for_templates }['speaking_engagements'].to_h { |s| [s['url'].to_s, s['icon']] }

    assert_equal %w[youtube], icons.select { |url, _| url.include?('youtube.com') }.values.uniq
    assert_equal %w[bookmark], icons.select { |url, _| url.include?('substack.com') }.values.uniq
    assert_equal [nil], icons.select { |url, _| url.include?('luma.com') }.values.uniq
    icon = ->(url) { StephenReid::SPEAKING_ICONS.find { |pattern, _| url.match?(pattern) }.last }

    assert_equal %w[spotify facebook], %w[https://open.spotify.com/episode/x https://www.facebook.com/events/1].map(&icon)
  end

  test "before the site's built, gives it its data, the build's version for the cache, and the courses in the nav" do
    site.data['nav'] = [{ 'name' => 'Courses', 'items' => [{ 'name' => 'All courses' }] }]
    with_env('GITHUB_SHA' => 'abc123') { with_fetched { Jekyll::Hooks.trigger(:site, :post_read, site) } }

    assert_equal 'abc123', site.config['cachebuster']
    assert_equal BOOKS.count { |b| b[:date_read] }, site.data['books'].size
    items = site.data['nav'].first['items']

    assert_equal 'All courses', items.first['name']
    assert_equal COURSES.sort_by { |c| c[:date] }.reverse.map { |c| "/courses/#{c[:slug]}" }, items.drop(1).pluck('path')
  end
end
