# A course's notes, from the HTML export of its Google Doc in github.com/stephenreid321/courses, tidied up
module Course
  # Fetches each course in data/courses.csv into data/fetched/courses.json, by slug: its head and body
  def self.fetch
    Fetched.write(:courses, COURSES.to_h { |course| [course[:slug], notes(course)] })
  end

  def self.notes(course)
    base_uri = "https://raw.githubusercontent.com/stephenreid321/courses/main/#{ERB::Util.url_encode(course[:name])}"
    response = Faraday.get("#{base_uri}/course.html")
    raise "#{course[:name]}: #{response.status}" unless response.success?

    doc = Nokogiri::HTML(response.body.force_encoding('UTF-8'))
    head = doc.search('head')
    body = doc.search('body')

    body.search('a[id^=cmnt_ref]').each { |a| a.parent.remove }
    body.search('a[id^=cmnt]').each { |a| a.parent.parent.remove }

    body.search('img').each do |img|
      img['src'] = "#{base_uri}/#{img['src']}"
      img.remove_attribute('style') if img['style'] && img['style'].match(/width:\s*([\d.]+)px/) && Regexp.last_match(1).to_i >= 576
      img.parent.remove_attribute('style') if img.parent.name == 'span'
      img.remove_attribute('style') if img.ancestors('table').any?
      # Remove negative margin values from image style
      next unless img['style'] && img['style'].match(/margin(-\w+)?:\s*-[\d.]+/)

      img['style'] = img['style'].gsub(/margin(-\w+)?:\s*-[\d.]+[^;]*;?/, '')
      # Remove style attribute if it's empty after the replacement
      img.remove_attribute('style') if img['style'].strip.empty?
    end

    # Add class to the first image
    first_img = body.at('img')
    first_img['class'] = 'first-image' if first_img

    body.search('a').each do |link|
      # Add a YouTube icon to YouTube links
      link.inner_html = %(<img src="/images/youtube.png" class="youtube-icon">#{link.inner_html}) if link['href'] && link['href'].include?('youtube') && link.parent == link.parent.parent.children.first

      # Remove Google redirect from URLs
      google_redirect = link['href'] && link['href'].match(%r{google\.com/url\?q=(.+?)(&|$)})
      link['href'] = URI.decode_www_form_component(google_redirect[1]) if google_redirect

      # Shorten very long link text
      link.content = "#{link.content.split('/').first(3).join('/')}/..." if link.content.start_with?('https://') && link.content.length >= 100
    end

    # Remove empty paragraph elements before and after unordered lists
    body.search('ul').each do |ul|
      [ul.previous_element, ul.next_element].each do |sibling|
        sibling.remove if sibling && sibling.name == 'p' && sibling.text.strip.empty? && sibling.search('img').empty?
      end
    end

    # Remove all empty paragraph elements
    body.search('p').each do |paragraph|
      paragraph.remove if paragraph.text.strip.empty? && paragraph.search('img').empty?
    end

    # Set margin-bottom: 0 for paragraphs containing anchor links that start with #
    body.search('a').each do |link|
      next unless link['href'] && link['href'].start_with?('#')

      parent_p = link.ancestors('p').first
      parent_p['class'] = "#{parent_p['class'] || ''} bottom-padding-10".strip if parent_p
    end

    { 'head' => head.inner_html.to_s.gsub('"Overpass"', 'sans-serif'), 'body' => body.inner_html }
  end
end
