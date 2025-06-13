require 'mechanize'
require 'reverse_markdown'

# $("a[href^='https://substack.com/@stephenreid?utm_source=substack-feed-item&utm_content=c-']").each(function() { console.log($(this).attr('href')) })

note_urls = File.read('note_urls.txt').split("\n")
attrs_to_remove = %w[
  class style id
  aria-expanded aria-haspopup aria-controls aria-label arialabel aria-describedby aria-hidden aria-live aria-atomic aria-relevant aria-busy aria-dropeffect aria-grabbed
  data-testid data-cy data-test data-qa data-automation data-track data-analytics data-gtm data-layer data-event data-action data-category data-label data-value
  role tabindex accesskey
  onclick onmouseover onmouseout onfocus onblur onload onerror onchange onsubmit onkeydown onkeyup onkeypress
  target rel download ping referrerpolicy hreflang type
  width height align valign bgcolor border cellpadding cellspacing
  autocomplete autocapitalize spellcheck contenteditable draggable dropzone
  hidden disabled readonly required placeholder maxlength minlength pattern
  title alt longdesc usemap coords shape
  lang dir translate
  itemscope itemtype itemprop itemid itemref
  nonce integrity crossorigin
]
nodes_to_remove = %w[svg button]

unless File.exist?('notes.html')
  output = ''
  agent = Mechanize.new
  note_urls.each do |url|
    url = "https://substack.com/@stephenreid/note/#{url.split('=').last}"
    puts url
    page = agent.get(url)
    if (note = page.search("[class*='feedPermalinkUnit']").first)
      # Remove all class attributes from the note and its children
      attrs_to_remove.each do |attr|
        note.remove_attribute(attr)
      end
      note.css('*').each do |element|
        attrs_to_remove.each do |attr|
          element.remove_attribute(attr)
        end
      end
      # Remove button elements
      nodes_to_remove.each do |node|
        note.css(node).remove
      end

      # Fix relative URLs starting with /
      note.css('a[href^="/"]').each do |link|
        href = link['href']
        link['href'] = "https://substack.com#{href}"
      end

      output << note.to_html
      output << "\n\n<hr/>\n\n"
    else
      puts page.body
      return
    end
  end

  File.write('notes.html', output)
end

# Write markdown file
File.write('notes.md', ReverseMarkdown.convert(output, github_flavored: true, unknown_tags: :bypass))
