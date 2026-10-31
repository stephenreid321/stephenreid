# Hands the templates the site's data (data/'s CSVs, and what rake data:fetch put in data/fetched), gives them the
# cdn_tag and cdn_dependencies tags, and makes the pages that have no template of their own: the courses' notes, the
# text exports and the redirects
require_relative '../../config/boot'

module StephenReid
  # Short and old URLs, and where they go
  REDIRECTS = {
    '/z' => 'https://zoom.us/j/9082171779',
    '/cal' => 'https://cal.com/stephenreid',
    '/meet' => 'https://cal.com/stephenreid/meet',
    '/ooo' => 'https://app.cal.com/settings/my-account/out-of-office',
    '/15' => 'https://cal.com/stephenreid/15',
    '/30' => 'https://cal.com/stephenreid/30',
    '/60' => 'https://cal.com/stephenreid/60',
    '/about' => '/',
    '/link' => '/',
    '/training' => '/',
    '/bio' => '/',
    '/darknet' => 'https://dark.fail/',
    '/why-use-the-darknet' => 'https://dark.fail/',
    '/books-videos' => '/',
    '/featured' => '/',
    '/recommended' => '/',
    '/knowledgegraph' => '/',
    '/maps' => 'https://lifeaspractice.com/',
    '/life-as-practice' => 'https://lifeaspractice.com/',
    '/technological-metamodernism' => 'https://stephenreid.substack.com/p/technological-metamodernism-course',
    '/context' => '/context.txt',
    '/substack/notes' => '/substack/notes.txt',
    '/substack/posts' => '/substack/posts.txt'
  }.freeze

  # The icon for a speaking engagement's link, by where it goes
  SPEAKING_ICONS = { /youtu/ => 'youtube', /spotify/ => 'spotify', /substack/ => 'bookmark', /google/ => 'google',
                     %r{facebook\.com/events/} => 'facebook' }.freeze

  module SiteData
    def self.for_templates
      {
        'books' => BOOKS.select { |b| b[:date_read] }.sort_by { |b| b[:date_read] }.reverse.map do |book|
          date_read = Date.parse(book[:date_read])
          book.slice(:book_id, :title, :cover_image).merge(tooltip: ("Read #{date_read.strftime('%b %Y')}" if date_read > Date.parse('2020-01-01'))).stringify_keys
        end,
        'books_updated' => last_changed('data/goodreads_library_export.csv'),
        'films' => FILMS.map(&:stringify_keys),
        'speaking_engagements' => SPEAKING_ENGAGEMENTS.reject { |s| s[:hidden] }.map do |s|
          s.merge(icon: SPEAKING_ICONS.find { |pattern, _| s[:url].to_s.match?(pattern) }&.last).stringify_keys
        end,
        'substack_gallery' => SubstackNote.recent_gallery_items(limit: 20).map(&:stringify_keys),
        'places' => Fetched.read(:places),
        'iconomi' => IconomiPages.iconomi,
        'metastrategy' => IconomiPages.metastrategy
      }
    end

    # When the file was last committed, or changed if it hasn't been
    def self.last_changed(path)
      committed = `git -C #{ROOT} log -1 --format=%cI -- #{path} 2>/dev/null`.strip
      committed.presence || File.mtime(File.join(ROOT, path)).iso8601
    end

    # data/courses.csv's courses, newest first, for the nav's Courses menu
    def self.nav_courses
      COURSES.sort_by { |c| c[:date] || Time.now.to_s }.reverse.map { |c| { 'name' => c[:name], 'path' => "/courses/#{c[:slug]}" } }
    end
  end

  Jekyll::Hooks.register :site, :post_read do |site|
    IconomiPages.reset!
    site.config['cachebuster'] = ENV['GITHUB_SHA'] || Time.now.to_i.to_s
    # The screenshot service that makes each page's og:image
    site.config['apiflash_key'] = ENV['APIFLASH_KEY'].presence if Jekyll.env == 'production'
    site.data.merge!(SiteData.for_templates)
    site.data['nav'].find { |item| item['name'] == 'Courses' }['items'] += SiteData.nav_courses
  end

  # Pages made from data rather than from a template of their own
  class Pages < Jekyll::Generator
    safe true

    def generate(site)
      redirects = REDIRECTS.merge(BOOKS.to_h { |b| ["/books/#{b[:slug]}", "https://www.goodreads.com/book/show/#{b[:book_id]}"] })
      redirects.each { |from, to| site.pages << page(site, "#{from}.html", redirect_html(to)) }

      {
        'context.txt' => -> { ::Context.markdown },
        'substack/notes.txt' => -> { SubstackNote.markdown_export },
        'substack/posts.txt' => -> { SubstackPost.markdown_export }
      }.each { |path, content| site.pages << page(site, path, content.call) }

      notes = Fetched.read(:courses, {})
      COURSES.each do |course|
        next Jekyll.logger.warn('Courses:', "no notes for #{course[:name]}: run rake data:courses") unless notes[course[:slug]]

        site.pages << page(site, "courses/#{course[:slug]}.html", notes[course[:slug]]['body'], 'layout' => 'course',
                                                                                                'course' => course.stringify_keys, 'head' => notes[course[:slug]]['head'])
      end
    end

    private

    # A page at path with this content, taken as it is rather than as Liquid
    def page(site, path, content, data = {})
      Jekyll::PageWithoutAFile.new(site, site.source, File.dirname(path).delete_prefix('/'), File.basename(path)).tap do |page|
        page.content = content
        page.data.merge!('layout' => nil, 'render_with_liquid' => false).merge!(data)
      end
    end

    def redirect_html(url)
      url = CGI.escapeHTML(url)
      <<~HTML
        <!doctype html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <title>Redirecting…</title>
            <link rel="canonical" href="#{url}">
            <meta http-equiv="refresh" content="0; url=#{url}">
            <meta name="robots" content="noindex">
          </head>
          <body>
            <a href="#{url}">Redirecting to #{url}</a>
          </body>
        </html>
      HTML
    end
  end

  # A script or stylesheet from jsDelivr: an npm package's file, at the version in config/frontend_package.json, or a URL. Its
  # hash from config/frontend_integrity.json is its integrity attribute, so the browser won't run it if it changes
  def self.cdn_tag(package_or_url, file = nil, **attributes)
    url = file ? FRONTEND_NPM_URL.call(package_or_url, file) : package_or_url
    attributes = attributes.merge(integrity: FRONTEND_INTEGRITY.fetch(url), crossorigin: 'anonymous')
    if url.end_with?('.css')
      "<link #{html_attributes(attributes.merge(rel: 'stylesheet', href: url))}>"
    else
      "<script #{html_attributes(attributes.merge(src: url))}></script>"
    end
  end

  def self.html_attributes(attributes)
    attributes.map { |k, v| %(#{k}="#{CGI.escapeHTML(v.to_s)}") }.join(' ')
  end

  # {% cdn_tag 'chart.js', 'dist/chart.umd.min.js' %}, or {% cdn_tag 'https://...' %}
  class CdnTag < Liquid::Tag
    def initialize(tag_name, markup, tokens)
      super
      @arguments = markup.scan(/['"]([^'"]+)['"]/).flatten
    end

    def render(_context)
      StephenReid.cdn_tag(*@arguments)
    end
  end

  # {% cdn_dependencies %}: the files every page loads (config/frontend_dependencies.rb)
  class CdnDependencies < Liquid::Tag
    def render(_context)
      tags = FRONTEND_DEPENDENCIES.flat_map do |package, files|
        files.split.map { |f| StephenReid.cdn_tag(package, f, **(FRONTEND_MODULES.include?(package) ? { type: 'module' } : {})) }
      end
      (tags + FRONTEND_URLS.map { |url| StephenReid.cdn_tag(url) }).join("\n")
    end
  end
end

Liquid::Template.register_tag('cdn_tag', StephenReid::CdnTag)
Liquid::Template.register_tag('cdn_dependencies', StephenReid::CdnDependencies)
