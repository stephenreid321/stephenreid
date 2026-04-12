module Prompt
  def self.prompt(book_summaries: false, notes_limit: nil, posts_limit: nil)
    sections = [
      {
        title: 'Short bio in the third person',
        content: File.read("#{Padrino.root}/app/markdown/bio.md").force_encoding('utf-8')
      },
      {
        title: 'Training and teachers',
        content: File.read("#{Padrino.root}/app/markdown/training.md").force_encoding('utf-8')
      },
      {
        title: 'Speaking engagements',
        content: SpeakingEngagement.all(filter: '{Hidden} = 0', sort: { 'Date' => 'desc' }).map { |speaking_engagement| "#{[speaking_engagement['Date'], speaking_engagement['Location'], speaking_engagement['Organisation Name']].compact.join(', ')}: #{speaking_engagement['Name']}" }.join("\n\n")
      },
      {
        title: 'Life as Practice',
        content: File.read("#{Padrino.root}/app/markdown/life_as_practice.md").force_encoding('utf-8')
      },
      {
        title: 'Coaching',
        content: File.read("#{Padrino.root}/app/markdown/coaching.md").force_encoding('utf-8')
      },
      {
        title: "Content I've shared recently",
        posts: Post.all(filter: "IS_AFTER({Created at}, '#{3.months.ago.to_s(:db)}')", sort: { 'Created at' => 'desc' }).map { |post| { title: post['Title'], link: post['Link'], date: post['Created at'], body: post['Body'] } }
      }
    ]

    sections << if book_summaries
                  {
                    title: "Books I've read, with summaries",
                    books: Book.all(sort: { 'Date Read' => 'desc' }, filter: "{Date Read} >= '2018-01-01'").map { |b| { title: b['Title'], author: b['Author'], date_read: b['Date Read'], summary: b['Summary'].blank? ? '(summary missing)' : b['Summary'].split("\n\n")[1..-1].join("\n\n") } }
                  }
                else
                  {
                    title: "Books I've read",
                    books: Book.all(sort: { 'Date Read' => 'desc' }, filter: "{Date Read} >= '2018-01-01'").map { |b| { title: b['Title'], author: b['Author'], date_read: b['Date Read'] } }
                  }
                end

    sections << {
      title: 'Substack notes',
      content: substack_notes_markdown(limit: notes_limit)
    }
    sections << {
      title: 'Substack posts',
      content: substack_posts(limit: posts_limit)
    }

    { document: { section: sections } }
  end

  def self.markdown(book_summaries: false, notes_limit: nil, posts_limit: nil)
    data = prompt(
      book_summaries: book_summaries,
      notes_limit: notes_limit,
      posts_limit: posts_limit
    )
    sections = data[:document][:section]

    sections.map do |section|
      result = ["## #{section[:title]}"]

      if section[:content]
        result << section[:content]
      elsif section[:posts]
        result << section[:posts].map { |post| "[#{post[:title]}](#{post[:link]}), #{post[:date]}\n#{post[:body]}" }.join("\n\n")
      elsif section[:books]
        result << if section[:title].include?('summaries')
                    section[:books].map { |b| "### #{b[:title]} by #{b[:author]} (read #{b[:date_read]})\n\n#{b[:summary]}" }.join("\n\n")
                  else
                    section[:books].map { |b| "#{b[:title]} by #{b[:author]} (read #{b[:date_read]})\n" }.join("\n")
                  end
      end

      result.join("\n\n")
    end
  end

  def self.xml(book_summaries: false, notes_limit: nil, posts_limit: nil)
    data = prompt(
      book_summaries: book_summaries,
      notes_limit: notes_limit,
      posts_limit: posts_limit
    )
    sections = data[:document][:section]

    sections.map do |section|
      section_hash = { title: section[:title] }

      if section[:content]
        section_hash[:content] = section[:content]
      elsif section[:posts]
        section_hash[:post] = section[:posts]
      elsif section[:books]
        section_hash[:book] = section[:books]
      end

      section_hash.to_xml(root: 'section', skip_instruct: true)
    end
  end

  # Splits notes.md into chunks (delimiter must match export_notes.rb).
  # Export order is newest-first, so the first chunks are the most recent notes.
  def self.substack_notes_markdown(limit: nil)
    substack_note_separator = '<!-- substack-note-separator -->'.freeze

    path = "#{Padrino.root}/app/substack/notes.md"
    full = File.read(path).force_encoding('utf-8')
    n = limit.to_i
    return full if n <= 0

    full = full.gsub("\r\n", "\n").sub(/\A\uFEFF/, '')
    escaped = Regexp.escape(substack_note_separator)
    parts = full.split(/\n#{escaped}\n/)
    parts = full.split("\n* * *\n") if parts.length == 1 && !full.include?(substack_note_separator)
    parts = parts.map(&:strip).reject(&:empty?)
    return full if parts.empty? || parts.length <= n

    parts.first(n).join("\n#{substack_note_separator}\n")
  rescue Errno::ENOENT
    ''
  end

  def self.substack_posts(limit: nil)
    posts = Dir["#{Padrino.root}/app/substack/posts/*.html"]
            .sort_by { |file| file.split('/').last.split('.').first.to_i }
    posts = posts.reverse

    csv_posts = CSV.read("#{Padrino.root}/app/substack/posts.csv", headers: true)

    posts = posts[0..(limit.to_i - 1)] if limit

    posts.reverse.map do |file|
      post_id = file.split('/').last.gsub('.html', '')
      post = csv_posts.find { |row| row['post_id'] == post_id }

      doc = Nokogiri::HTML(
        "<h1>#{post['title']}, #{post['post_date']}</h1>
            #{File.read(file).gsub(/<source.*?>/, '')}"
      )
      doc.search('div.image2-inset').each do |tag|
        tag.replace(tag.children)
      end
      doc.search('picture').each do |tag|
        tag.replace(tag.children)
      end
      doc.search('div.image-link-expand').remove
      doc.search('img').each do |tag|
        tag['src'] = tag['srcset'].split(' ')[-2] if tag['srcset']
      end

      ReverseMarkdown.convert(doc.to_html.gsub('<div></div>', ''))
    end.join("\n")
  end
end
