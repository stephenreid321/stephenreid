require 'test_config'

# lib/course.rb: a course's notes, from the HTML export of its Google Doc, tidied up
class CoursesCourseTest < ActiveSupport::TestCase
  COURSE = { name: 'Life as Practice (Sep 2022)', slug: 'life-as-practice-sep-2022' }.freeze
  BASE = 'https://raw.githubusercontent.com/stephenreid321/courses/main/Life%20as%20Practice%20%28Sep%202022%29'.freeze

  EXPORT = <<~HTML.freeze
    <html>
      <head><style>body { font-family: "Overpass"; }</style></head>
      <body>
        <p><span><img src="images/image1.png" style="width: 624.00px; height: 300.00px;"></span></p>
        <p><img src="images/image2.png" style="width: 200px; margin-left: -12.5px;"></p>
        <table><tr><td><img src="images/image3.png" style="width: 100px;"></td></tr></table>
        <p>Read <a href="https://www.google.com/url?q=https://example.com/a%3Fb%3D1&amp;sa=D">this</a><sup><a id="cmnt_ref1" href="#cmnt1">[a]</a></sup></p>
        <ul><li><span><a href="https://www.youtube.com/watch?v=x">A talk</a></span> and more</li></ul>
        <p> </p>
        <p><a href="https://example.com/#{'a' * 100}">https://example.com/#{'a' * 100}</a></p>
        <p><a href="#heading">Jump to the heading</a></p>
        <p>   </p>
        <div><p><a id="cmnt1" href="#cmnt_ref1">[a]</a> A comment on the doc</p></div>
      </body>
    </html>
  HTML

  def notes(body = EXPORT, status = 200)
    stub_http { |stub| stub.get("#{BASE}/course.html") { [status, {}, body.dup] } }
    Course.notes(COURSE)
  end

  def body
    @body ||= Nokogiri::HTML.fragment(notes['body'])
  end

  test "takes out the doc's comments, and the marks where they were" do
    refute_includes body.to_html, 'cmnt'
    refute_includes body.text, 'A comment on the doc'
    assert_includes body.text, 'Read this'
  end

  test 'loads the images from the repo, at the width the page gives them, and marks the first' do
    images = body.css('img:not(.youtube-icon)')

    assert_equal %w[image1 image2 image3].map { |i| "#{BASE}/images/#{i}.png" }, images.pluck('src')
    assert_equal ['first-image', nil, nil], images.pluck('class')
    # As wide as the page, or wider, or in a table: no width of its own. Nor a negative margin, or the span's style
    assert_equal [nil, 'width: 200px; ', nil], images.pluck('style')
    assert_nil images.first.parent['style']
  end

  test "goes straight to a link's page, not through Google, shortens a long URL, and marks YouTube's" do
    links = body.css('a')

    assert_equal 'https://example.com/a?b=1', links.first['href']
    assert_equal 'https://example.com/...', links.find { |a| a['href'].include?('aaaa') }.text
    youtube = links.find { |a| a['href'].include?('youtube') }

    assert_equal '<img src="/images/youtube.png" class="youtube-icon">A talk', youtube.inner_html
  end

  test 'takes out the empty paragraphs, but not those with an image, and spaces those of links within the page' do
    paragraphs = body.css('p')

    assert(paragraphs.all? { |p| p.text.strip.present? || p.at('img') })
    assert_equal 'bottom-padding-10', body.at('a[href="#heading"]').parent['class']
  end

  test "keeps the doc's styles, but in the site's font" do
    assert_includes notes['head'], '<style>body { font-family: sans-serif; }</style>'
  end

  test "fails if the repo doesn't have the course" do
    assert_match(/Life as Practice \(Sep 2022\): 404/, assert_raises(RuntimeError) { notes('Not found', 404) }.message)
  end

  test 'fetches every course into data/fetched/courses.json, by slug' do
    stub_http { |stub| stub.get(%r{/course\.html\z}) { [200, {}, EXPORT.dup] } }
    courses = fetched_after { Course.fetch }['courses']

    assert_equal COURSES.pluck(:slug), courses.keys
    assert_equal %w[head body], courses.values.first.keys
  end
end
