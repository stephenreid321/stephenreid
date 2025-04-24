require 'nokogiri'
require 'reverse_markdown'
require 'uri'

# Module to convert Substack Notes HTML feed to Markdown
module SubstackNotesConverter
  # Public method to perform the conversion.
  #
  # @param html_content [String] The HTML content of the Substack Notes feed.
  # @param base_url [String] The base URL for resolving relative links (defaults to Substack).
  # @return [String] The converted Markdown content.
  def self.convert(html_content:, base_url: 'https://substack.com')
    doc = Nokogiri::HTML(html_content)
    markdown_notes = []

    doc.css('div.feedItem-ONDKv3').each do |note_div|
      note_parts = []

      restack_info = extract_restack_info(note_div, base_url)
      note_parts << restack_info if restack_info

      author_time_info = extract_author_time(note_div, base_url)
      note_parts << author_time_info if author_time_info

      content_info = extract_content(note_div, base_url)
      note_parts << content_info if content_info && !content_info.strip.empty?

      attachment_info = extract_attachments(note_div, base_url)
      note_parts << attachment_info if attachment_info

      # Add the formatted note (filtering empty parts) to the main array
      # Join sections within a note with double newlines
      markdown_notes << note_parts.compact.reject(&:empty?).join("\n\n")
    end

    # Join separate notes with a clear separator (horizontal rule and newlines)
    markdown_notes.join("\n\n---\n\n")
  end

  # --- Private Helper Methods ---

  # Safely extract text, returning nil if node is nil
  def self.safe_text(node)
    node&.text&.strip
  end

  # Safely extract attribute, returning nil if node is nil
  def self.safe_attr(node, attr_name)
    node&.attr(attr_name)&.strip
  end

  # Make URLs absolute if they are relative
  def self.make_absolute_url(href, base_url)
    return nil unless href && base_url

    # Handle protocol-relative URLs like //substackcdn.com/...
    href = 'https:' + href if href.start_with?('//')
    uri = URI.parse(href)
    return href if uri.absolute? # Check if already absolute

    base = URI.parse(base_url)
    # Ensure base has a scheme for merging
    base.scheme = 'https' unless base.scheme
    base.merge(uri).to_s
  rescue URI::InvalidURIError, URI::BadURIError
    # If merging fails, try simple concatenation for path-only hrefs
    return File.join(base_url, href) if href.start_with?('/') && !base_url.end_with?('/')
    return base_url + href if href.start_with?('/') && base_url.end_with?('/')

    href # Return original if all else fails
  end

  # Converts specific HTML content node to Markdown with cleanup
  def self.convert_html_to_markdown(node, base_url)
    return '' unless node

    # Configure ReverseMarkdown for cleaner output
    ReverseMarkdown.config.unknown_tags = :bypass # Keep unknown tags
    ReverseMarkdown.config.github_flavored = true

    # Clone node to avoid modifying original during conversion
    content_node = node.dup

    # Simplify mentions
    content_node.css('span.node-substack_mention').each do |mention_span|
      link_node = mention_span.at_css('a.mention-LUD0tW')
      if link_node
        mention_text = safe_text(link_node)
        mention_href = make_absolute_url(safe_attr(link_node, 'href'), base_url)
        mention_span.replace("[@#{mention_text}](#{mention_href})") if mention_text && mention_href
      else
        mention_span.replace(safe_text(mention_span)) # Fallback
      end
    end

    # Simplify other specific links if needed (e.g., short internal links)
    content_node.css('a.note-link').each do |link|
      href = make_absolute_url(safe_attr(link, 'href'), base_url)
      text = safe_text(link)
      # Prefer URL if text is truncated or generic, otherwise use text
      display_text = text&.include?('…') || text&.downcase == 'link' || text == href ? href : text
      link.replace("[#{display_text}](#{href})") if href
    end

    # Convert the cleaned HTML
    markdown = ReverseMarkdown.convert(content_node.inner_html)

    # Further cleanups
    markdown.gsub!(/\n{3,}/, "\n\n") # Reduce excessive newlines
    markdown.gsub!(/^\\/, '') # Remove potential leading backslashes from escaped characters
    markdown.strip
  end

  # Extracts restack information if present.
  def self.extract_restack_info(note_div, base_url)
    restack_node = note_div.at_css('.contextRow-x_1iaF')
    return nil unless restack_node

    restacker_link_node = restack_node.at_css('a.link-LIBpto')
    restacker_name = safe_text(restacker_link_node) || 'Someone'
    restacker_url = make_absolute_url(safe_attr(restacker_link_node, 'href'), base_url) || '#'
    action_text = safe_text(restack_node)&.gsub(/#{Regexp.escape(restacker_name)}/i, '')&.strip
    action_text ||= 'restacked' # Fallback action text

    "*#{action_text.capitalize} by [#{restacker_name}](#{restacker_url})*"
  end

  # Extracts author name, link, and time information.
  # MODIFIED: Prioritizes absolute time for display.
  def self.extract_author_time(note_div, base_url)
    main_content_block = note_div.at_css('.pc-display-flex.pc-gap-12.pc-alignItems-flex-start')
    return '(Author/Time info not found)' unless main_content_block

    # --- Author ---
    author_name_node = main_content_block.at_css('span.weight-medium-fw81nC a.link-LIBpto')
    author_name = safe_text(author_name_node)
    # Fallback to avatar title
    author_name ||= safe_attr(main_content_block.at_css('.container-TAtrWj[title]'), 'title')
    # Default if still not found
    author_name ||= 'Unknown Author'

    # Find the best link (name link or avatar link)
    author_link_node = author_name_node || main_content_block.at_css('a.animate-XFJxE4')
    author_url = make_absolute_url(safe_attr(author_link_node, 'href'), base_url)

    # --- Timestamp ---
    # Look for a link with a year in its title attribute (most reliable indicator)
    time_link_node = main_content_block.at_css('a.link-LIBpto[title*=" 20"]')
    absolute_time = safe_attr(time_link_node, 'title') # Get the full date/time
    permalink = make_absolute_url(safe_attr(time_link_node, 'href'), base_url)

    # --- Formatting ---
    author_md = author_url ? "[#{author_name}](#{author_url})" : author_name

    time_md = ''
    if absolute_time
      time_md = if permalink
                  "[#{absolute_time}](#{permalink})" # Link the absolute time
                else
                  "_#{absolute_time}_" # Absolute time without link (italicized)
                end
    else
      # Fallback: Check if there's a relative time display text as a last resort
      relative_time = safe_text(time_link_node)
      time_md = if relative_time && permalink
                  "[#{relative_time}](#{permalink})" # Use relative if absolute missing
                else
                  '(Time not found)' # No time information found
                end
    end

    "**#{author_md}** #{time_md}"
  end

  # Extracts the main content/body of the note.
  def self.extract_content(note_div, base_url)
    main_content_block = note_div.at_css('.pc-display-flex.pc-gap-12.pc-alignItems-flex-start')
    return '' unless main_content_block

    content_node = main_content_block.at_css('.ProseMirror.FeedProseMirror, .feedCommentBodyInner-AOzMIC .ProseMirror')
    markdown = convert_html_to_markdown(content_node, base_url) # Pass base_url

    # Append ellipsis if "See more" is present and content exists
    markdown += ' [...]' if main_content_block.at_css('.seeMore-D88zkH') && !markdown.empty? && !markdown.end_with?(' [...]')
    markdown
  end

  # Extracts attachments like linked articles, images, or embeds.
  # MODIFIED: Uses a broader selector to find attachments regardless of pc-display-contents wrapper.
  def self.extract_attachments(note_div, base_url)
    # Find the main column holding author/time, content, and attachments
    note_body_container = note_div.at_css('.pc-display-flex.pc-flexDirection-column.pc-gap-8.pc-minWidth-0.flexGrow-tjePuI')
    return nil unless note_body_container

    attachments_md = []
    # Search *within* this main column for known attachment elements/wrappers
    # This is more robust to variations in nesting like pc-display-contents
    attachment_nodes = note_body_container.css(
      'a.postAttachment-eYV3fM, a.container-KbMeLj, a.attachment-E9mJrI, ' + # Link types
      'div.imageGrid-TadIyX, div.imageCarouselContainer-Y1hu48, ' + # Image types
      'div.spotify-cCmxPs, div.youtube-AgNZc0' # Embed types
    )

    attachment_nodes.each do |attach|
      attachment_markdown = nil
      # Determine the type of attachment based on its tag name or classes
      if attach.name == 'a' # Link-based attachments (posts, quotes, generic links)
        href = make_absolute_url(safe_attr(attach, 'href'), base_url)
        title_node = attach.at_css('.color-primary-zABazT, .color-vibrance-primary-KHCdqV, .size-15-Psle70')
        title = safe_text(title_node) || 'Link'
        domain_node = attach.at_css('.color-secondary-ls1g8s, .color-vibrance-secondary-k5eqjt, .size-13-hZTUKr')
        domain = safe_text(domain_node)

        # Check specifically for quoted text using the specific text class
        quote_text_node = attach.at_css('.text-RPsawq')
        if quote_text_node
          quote_text = safe_text(quote_text_node)
          # Source might be in the domain field or a specific author field
          quote_source = safe_text(attach.at_css('.font-text-qe4AeH.size-13-hZTUKr')) || domain || 'Source'
          attachment_markdown = "> #{quote_text.gsub("\n", "\n> ")}\n> — #{quote_source}" if quote_text
        elsif href # Normal link attachment
          # Avoid showing domain if it's already obvious from the title or link
          domain_text = domain && !domain.empty? && !title.include?(domain) && !href.include?(domain) ? " (#{domain})" : ''
          attachment_markdown = "> Attachment: [#{title}](#{href})#{domain_text}"
        end

      elsif attach['class']&.include?('imageGrid') || attach['class']&.include?('imageCarousel') # Image types
        img_mds = []
        attach.css('img').each do |img|
          img_src = safe_attr(img, 'src') # Prioritize src
          # Basic srcset handling
          if !img_src || img_src.include?('placeholder') || img_src.start_with?('data:') || img_src.match?(/\W1w$/)
            srcset = safe_attr(img, 'srcset')
            img_src = srcset.split(',').map(&:strip).find { |s| !s.start_with?('data:') && s.include?('http') }&.split(' ')&.first if srcset
          end
          img_src = make_absolute_url(img_src, base_url) if img_src
          alt_text = safe_attr(img, 'alt') || 'Image'
          img_mds << "![#{alt_text}](#{img_src})" if img_src
        end
        attachment_markdown = img_mds.join("\n") unless img_mds.empty?

      elsif attach.at_css('iframe') # Embed types (Spotify, YouTube)
        iframe = attach.at_css('iframe')
        embed_src = safe_attr(iframe, 'src')
        if embed_src
          embed_type = 'Media Embed'
          embed_type = 'Spotify Embed' if embed_src.include?('spotify')
          embed_type = 'YouTube Embed' if embed_src.include?('youtube')
          attachment_markdown = "> #{embed_type}: [#{embed_src}](#{embed_src})"
        end
      end # End of if/elsif chain for attachment types

      attachments_md << attachment_markdown if attachment_markdown
    end # end attachment_nodes.each

    # Return joined markdown string or nil if no attachments were found/formatted
    attachments_md.empty? ? nil : attachments_md.join("\n\n")
  end
end # module SubstackNotesConverter

# --- Example Usage ---
if __FILE__ == $0
  INPUT_HTML_FILE = 'notes.html'
  OUTPUT_MARKDOWN_FILE = 'notes_output_module.md'

  begin
    html = File.read(INPUT_HTML_FILE)
    puts "Read #{html.bytesize} bytes from #{INPUT_HTML_FILE}"

    markdown_result = SubstackNotesConverter.convert(html_content: html)

    if markdown_result && !markdown_result.strip.empty?
      File.write(OUTPUT_MARKDOWN_FILE, markdown_result)
      puts "Successfully converted notes to #{OUTPUT_MARKDOWN_FILE}"
    else
      puts 'Warning: Conversion produced empty or nil result. No output file written.'
    end
  rescue Errno::ENOENT
    puts "Error: Input file '#{INPUT_HTML_FILE}' not found."
  rescue StandardError => e
    puts 'An error occurred during conversion or writing:'
    puts "Error: #{e.message}"
    puts "Backtrace:\n#{e.backtrace.join("\n\t")}"
  end
end
