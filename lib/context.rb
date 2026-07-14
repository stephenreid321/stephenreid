module Context
  def self.context(book_summaries: false, notes_limit: nil, posts_limit: nil)
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
        content: SPEAKING_ENGAGEMENTS.reject { |s| s[:hidden] }.map do |speaking_engagement|
          name = speaking_engagement[:url].present? ? "[#{speaking_engagement[:name]}](#{speaking_engagement[:url]})" : speaking_engagement[:name]
          "#{[speaking_engagement[:date], speaking_engagement[:location], speaking_engagement[:organisation_name]].compact.join(', ')}: #{name}"
        end.join("\n\n")
      },
      {
        title: "Content I've shared recently",
        posts: Post.all(filter: "IS_AFTER({Created at}, '#{3.months.ago.to_s(:db)}')", sort: { 'Created at' => 'desc' }).map { |post| { title: post['Title'], link: post['Link'], date: post['Created at'], body: post['Body'] } }
      }
    ]

    sections << if book_summaries
                  {
                    title: "Books I've read, with summaries",
                    books: BOOKS.select { |b| b[:date_read] && b[:date_read] >= '2018-01-01' }.map { |b| { title: b[:title], author: b[:author], date_read: b[:date_read], summary: b[:summary].blank? ? '(summary missing)' : b[:summary].split("\n\n")[1..-1].join("\n\n") } }
                  }
                else
                  {
                    title: "Books I've read",
                    books: BOOKS.select { |b| b[:date_read] && b[:date_read] >= '2018-01-01' }.map { |b| { title: b[:title], author: b[:author], date_read: b[:date_read] } }
                  }
                end

    sections << {
      title: 'Substack notes',
      content: SubstackNote.markdown_export(limit: notes_limit).force_encoding('utf-8')
    }
    sections << {
      title: 'Substack posts',
      content: SubstackPost.markdown_export(limit: posts_limit).force_encoding('utf-8')
    }

    { document: { section: sections } }
  end

  def self.markdown(book_summaries: false, notes_limit: nil, posts_limit: nil)
    data = context(
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
    data = context(
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
end
